"""
org-mode Memory Connector

Конвертирует org-mode файлы в mem-agent формат через pandoc.
Поддерживает как отдельные файлы, так и целые директории.
"""

import os
import subprocess
from pathlib import Path
from typing import Dict, Any, List, Optional
import tempfile
import re
import hashlib
import json
from datetime import datetime

from memory_connectors.base import BaseMemoryConnector


class OrgModeConnector(BaseMemoryConnector):
    """Коннектор для org-mode файлов с использованием pandoc."""
    
    def __init__(self, output_path: str, **kwargs):
        super().__init__(output_path, **kwargs)
        self.skip_existing = kwargs.get('skip_existing', False)
        self.sync_metadata_file = self.output_path / '.org_sync_metadata.json'
        
    @property
    def connector_name(self) -> str:
        return "org-mode PKM Connector"
    
    @property 
    def supported_formats(self) -> list:
        return ['.org', 'directory']
    
    def extract_data(self, source_path: str) -> Dict[str, Any]:
        """Извлекает данные из org-mode файлов через pandoc с инкрементальным обновлением."""
        source = Path(source_path)
        
        if not source.exists():
            raise FileNotFoundError(f"Источник не найден: {source_path}")
        
        # Загружаем метаданные синхронизации
        sync_metadata = self._load_sync_metadata()
        
        org_files = []
        
        if source.is_file():
            if source.suffix == '.org':
                org_files = [source]
            else:
                raise ValueError(f"Файл должен иметь расширение .org: {source_path}")
        elif source.is_dir():
            org_files = list(source.rglob('*.org'))
            if not org_files:
                raise ValueError(f"Не найдено .org файлов в директории: {source_path}")
        
        print(f"🔍 Найдено {len(org_files)} org-файлов")
        
        # Фильтруем файлы для обработки (только измененные)
        files_to_process = []
        skipped_count = 0
        
        for org_file in org_files:
            if self._should_process_file(org_file, sync_metadata):
                files_to_process.append(org_file)
            else:
                skipped_count += 1
        
        print(f"📥 К обработке: {len(files_to_process)} файлов, пропущено: {skipped_count}")
        
        if not files_to_process:
            print("ℹ️  Все файлы актуальны, изменений нет")
            return {
                'files': [],
                'source_path': str(source),
                'total_files': 0,
                'skipped_files': skipped_count,
                'sync_metadata': sync_metadata
            }
        
        converted_files = []
        
        for org_file in files_to_process:
            print(f"📄 Конвертирую: {org_file.name}")
            
            # Проверяем наличие pandoc
            if not self._check_pandoc():
                raise RuntimeError("pandoc не найден. Установите pandoc для конвертации org-файлов.")
            
            # Конвертируем через pandoc
            try:
                with tempfile.NamedTemporaryFile(mode='w+', suffix='.md', delete=False) as tmp_file:
                    cmd = [
                        'pandoc',
                        str(org_file),
                        '-f', 'org',
                        '-t', 'markdown',
                        '-o', tmp_file.name
                    ]
                    
                    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
                    
                    # Читаем конвертированный markdown
                    with open(tmp_file.name, 'r', encoding='utf-8') as f:
                        markdown_content = f.read()
                    
                    # Удаляем временный файл
                    os.unlink(tmp_file.name)
                    
                    converted_files.append({
                        'filename': org_file.stem,
                        'original_path': str(org_file),
                        'content': markdown_content,
                        'relative_path': str(org_file.relative_to(source if source.is_dir() else source.parent)),
                        'org_file_obj': org_file  # Добавляем для обновления метаданных
                    })
                    
            except subprocess.CalledProcessError as e:
                print(f"⚠️  Ошибка конвертации {org_file.name}: {e.stderr}")
                continue
            except Exception as e:
                print(f"⚠️  Неожиданная ошибка при обработке {org_file.name}: {e}")
                continue
        
        if converted_files:
            print(f"✅ Успешно сконвертировано: {len(converted_files)} файлов")
        else:
            print("⚠️  Не удалось сконвертировать ни одного файла")
        
        return {
            'files': converted_files,
            'source_path': str(source),
            'total_files': len(converted_files),
            'skipped_files': skipped_count,
            'sync_metadata': sync_metadata
        }
    
    def organize_data(self, extracted_data: Dict[str, Any]) -> Dict[str, Any]:
        """Организует конвертированные данные в структуру памяти."""
        files = extracted_data['files']
        
        # Анализируем содержимое для категоризации
        entities = []
        user_info = None
        
        for file_data in files:
            content = file_data['content']
            filename = file_data['filename']
            
            # Определяем тип файла по содержимому
            if self._is_user_profile(content, filename):
                # Это профиль пользователя
                user_info = {
                    'filename': filename,
                    'content': content,
                    'type': 'user_profile',
                    'org_file_obj': file_data.get('org_file_obj')  # Добавляем для трекинга
                }
            else:
                # Это сущность
                entities.append({
                    'filename': filename,
                    'content': content,
                    'type': self._classify_entity_type(content, filename),
                    'original_path': file_data['original_path'],
                    'org_file_obj': file_data.get('org_file_obj')  # Добавляем для трекинга
                })
        
        # Если нет явного профиля пользователя, создаем базовый
        if not user_info:
            user_info = self._create_default_user_profile(extracted_data)
        
        return {
            'user_profile': user_info,
            'entities': entities,
            'metadata': {
                'source_path': extracted_data['source_path'],
                'conversion_method': 'pandoc',
                'total_files': len(files),
                'skipped_files': extracted_data.get('skipped_files', 0),
                'sync_metadata': extracted_data.get('sync_metadata', {})
            }
        }
    
    def generate_memory_files(self, organized_data: Dict[str, Any]) -> None:
        """Генерирует файлы памяти в mem-agent формате."""
        self.ensure_output_dir()
        
        entities_dir = self.output_path / "entities"
        entities_dir.mkdir(exist_ok=True)
        
        # Получаем метаданные синхронизации
        sync_metadata = organized_data['metadata'].get('sync_metadata', {})
        updated_files = []
        
        # Создаем user.md только если есть профиль пользователя
        user_profile = organized_data['user_profile']
        if user_profile and user_profile.get('content'):
            user_file = self.output_path / "user.md"
            print(f"📝 Создаю профиль пользователя: {user_file}")
            with open(user_file, 'w', encoding='utf-8') as f:
                f.write(self._enhance_user_profile(user_profile))
            
            # Обновляем метаданные для профиля пользователя тоже
            if 'org_file_obj' in user_profile:
                self._update_file_metadata(user_profile['org_file_obj'], 'user.md', sync_metadata)
                updated_files.append('user')
        
        # Создаем файлы сущностей
        entities = organized_data['entities']
        entity_links = []
        
        for entity in entities:
            entity_filename = f"{entity['filename']}.md"
            entity_file = entities_dir / entity_filename
            entity_links.append(f"- [[{entity['filename']}]] - {entity['type']}")
            
            print(f"📝 Создаю сущность: {entity_file}")
            with open(entity_file, 'w', encoding='utf-8') as f:
                f.write(self._enhance_entity_content(entity))
            
            # Обновляем метаданные для этого файла
            if 'org_file_obj' in entity:
                self._update_file_metadata(entity['org_file_obj'], entity_filename, sync_metadata)
                updated_files.append(entity['filename'])
        
        # Обновляем user.md с ссылками на сущности (только если есть новые)
        if entity_links and user_profile:
            user_file = self.output_path / "user.md"
            with open(user_file, 'a', encoding='utf-8') as f:
                f.write("\n\n## Связанные сущности из org-mode\n")
                f.write("\n".join(entity_links))
        
        # Сохраняем обновленные метаданные синхронизации
        self._save_sync_metadata(sync_metadata)
        
        total_files = len(entities)
        skipped_files = organized_data['metadata'].get('skipped_files', 0)
        
        if total_files > 0:
            print(f"✅ Обновлено файлов: user.md + {total_files} сущностей")
            print(f"📊 Обработано: {total_files}, пропущено: {skipped_files}")
            if updated_files:
                print(f"🔄 Обновленные файлы: {', '.join(updated_files[:5])}{'...' if len(updated_files) > 5 else ''}")
        else:
            print(f"ℹ️  Нет изменений для обновления (пропущено: {skipped_files})")
    
    def _check_pandoc(self) -> bool:
        """Проверяет наличие pandoc в системе."""
        try:
            subprocess.run(['pandoc', '--version'], capture_output=True, check=True)
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            return False
    
    def _is_user_profile(self, content: str, filename: str) -> bool:
        """Определяет, является ли файл профилем пользователя."""
        profile_indicators = [
            'about_me', 'profile', 'резюме', 'cv', 'bio',
            'самопрезентация', 'интервью', 'собеседование'
        ]
        
        filename_lower = filename.lower()
        content_lower = content.lower()
        
        # Проверяем имя файла
        for indicator in profile_indicators:
            if indicator in filename_lower:
                return True
        
        # Проверяем содержимое
        if any(word in content_lower for word in ['меня зовут', 'my name is', 'профессиональный опыт']):
            return True
        
        return False
    
    def _classify_entity_type(self, content: str, filename: str) -> str:
        """Классифицирует тип сущности по содержимому."""
        filename_lower = filename.lower()
        content_lower = content.lower()
        
        if any(word in filename_lower for word in ['nixos', 'linux', 'system']):
            return 'Системная документация'
        elif any(word in filename_lower for word in ['notes', 'заметки', 'todo']):
            return 'Личные заметки и задачи'
        elif any(word in content_lower for word in ['проект', 'project', 'разработка']):
            return 'Проект'
        elif any(word in content_lower for word in ['компания', 'работа', 'company']):
            return 'Организация'
        else:
            return 'Справочная информация'
    
    def _create_default_user_profile(self, extracted_data: Dict[str, Any]) -> Dict[str, Any]:
        """Создает базовый профиль пользователя."""
        return {
            'filename': 'user_profile',
            'content': f"""# Пользователь (из org-mode)

## Основная информация
- **Источник**: org-mode файлы из {extracted_data['source_path']}
- **Файлов обработано**: {extracted_data['total_files']}
- **Метод конвертации**: pandoc

## Personal Knowledge Management
Пользователь ведет заметки в org-mode формате, что указывает на:
- Использование Emacs как основного редактора
- Структурированный подход к управлению знаниями  
- Техническую грамотность и предпочтение текстовых форматов
""",
            'type': 'generated_profile'
        }
    
    def _enhance_user_profile(self, user_profile: Dict[str, Any]) -> str:
        """Улучшает профиль пользователя дополнительной информацией."""
        content = user_profile['content']
        
        # Добавляем метаинформацию о org-mode
        if user_profile['type'] == 'generated_profile':
            return content
        
        # Для реальных профилей добавляем контекст
        enhanced = f"""# Профиль пользователя (org-mode PKM)

*Конвертировано из org-mode через pandoc*

{content}

## Техническая среда
- **PKM система**: org-mode (Emacs)
- **Формат исходных файлов**: .org
- **Метод конвертации**: pandoc → markdown
"""
        return enhanced
    
    def _enhance_entity_content(self, entity: Dict[str, Any]) -> str:
        """Улучшает содержимое сущности метаданными."""
        content = entity['content']
        
        header = f"""# {entity['filename'].replace('_', ' ').title()}

*Тип: {entity['type']}*
*Источник: {entity['original_path']}*
*Конвертировано из org-mode*

---

{content}

---

*Связанные концепции будут автоматически обнаружены системой памяти*
"""
        return header
    
    def _load_sync_metadata(self) -> Dict[str, Any]:
        """Загружает метаданные синхронизации из файла."""
        if not self.sync_metadata_file.exists():
            return {
                'version': '1.0',
                'last_sync': None,
                'files': {}  # file_path -> {'hash': str, 'last_modified': str, 'output_file': str}
            }
        
        try:
            with open(self.sync_metadata_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        except (json.JSONDecodeError, FileNotFoundError):
            print("⚠️  Поврежденные метаданные синхронизации, создаю новые")
            return {
                'version': '1.0',
                'last_sync': None,
                'files': {}
            }
    
    def _save_sync_metadata(self, metadata: Dict[str, Any]) -> None:
        """Сохраняет метаданные синхронизации в файл."""
        metadata['last_sync'] = datetime.now().isoformat()
        self.ensure_output_dir()
        
        with open(self.sync_metadata_file, 'w', encoding='utf-8') as f:
            json.dump(metadata, f, indent=2, ensure_ascii=False)
    
    def _calculate_file_hash(self, file_path: Path) -> str:
        """Вычисляет SHA256 хеш содержимого файла."""
        hasher = hashlib.sha256()
        try:
            with open(file_path, 'rb') as f:
                # Читаем файл блоками для экономии памяти
                for chunk in iter(lambda: f.read(4096), b""):
                    hasher.update(chunk)
            return hasher.hexdigest()
        except (IOError, OSError) as e:
            print(f"⚠️  Ошибка чтения файла {file_path}: {e}")
            return ""
    
    def _should_process_file(self, org_file: Path, sync_metadata: Dict[str, Any]) -> bool:
        """Определяет, нужно ли обрабатывать файл."""
        if self.skip_existing:
            # В режиме skip-existing проверяем, существует ли уже выходной файл
            output_file = self.output_path / "entities" / f"{org_file.stem}.md"
            if output_file.exists():
                print(f"⏭️  Пропускаю существующий: {org_file.name}")
                return False
        
        file_path_str = str(org_file)
        current_hash = self._calculate_file_hash(org_file)
        
        if not current_hash:
            return False  # Не удалось прочитать файл
        
        # Проверяем метаданные
        if file_path_str in sync_metadata['files']:
            stored_data = sync_metadata['files'][file_path_str]
            if stored_data.get('hash') == current_hash:
                print(f"⏭️  Файл не изменился: {org_file.name}")
                return False
        
        return True
    
    def _update_file_metadata(self, org_file: Path, output_filename: str, sync_metadata: Dict[str, Any]) -> None:
        """Обновляет метаданные файла после обработки."""
        file_path_str = str(org_file)
        file_hash = self._calculate_file_hash(org_file)
        
        sync_metadata['files'][file_path_str] = {
            'hash': file_hash,
            'last_modified': datetime.fromtimestamp(org_file.stat().st_mtime).isoformat(),
            'output_file': output_filename,
            'processed_at': datetime.now().isoformat()
        }