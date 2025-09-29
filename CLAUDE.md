# CLAUDE.md

Этот файл предоставляет руководство для Claude Code (claude.ai/code) при работе с кодом в данном репозитории.

## Команды разработки

### Установка и настройка
```bash
make check-uv        # Проверить установку uv и установить при необходимости
make install         # Установить зависимости через uv
make setup           # Выбрать директорию памяти и настроить систему
```

### Запуск системы
```bash
make run-agent       # Запустить агента (автоматически определяет LM Studio, vLLM или предлагает альтернативы)
make serve-mcp       # Запустить MCP сервер через STDIO
make chat-cli        # Интерактивный CLI для общения с агентом
```

### Варианты локального сервера модели

**LM Studio (Рекомендуется для всех платформ):**
```bash
# Установить LM Studio, затем скачать модель
lms get driaforall/mem-agent
make run-agent       # Автоматически определяет LM Studio и запускает сервер
```

**NixOS с LM Studio:**
- Работает "из коробки", нет проблем совместимости с CUDA
- Автоматически определяется командой `make run-agent`
- Модель: `driaforall.mem-agent` (4B параметров, 2.38 ГБ)

**Альтернатива: OpenRouter API**
```bash
export OPENROUTER_API_KEY="ваш_ключ_api"
make chat-cli        # Использовать внешний API вместо локальной модели
```

### Управление памятью
```bash
make memory-wizard          # Интерактивный мастер подключения источников памяти
make connect-memory         # Подключить источники памяти (см. примеры ниже)
make add-filters           # Добавить фильтры в файл .filters
make reset-filters         # Сбросить фильтры в файле .filters
```

### Интеграция org-mode файлов
```bash
# Быстрая конвертация org-mode файлов в markdown
pandoc /path/to/file.org -f org -t markdown -o /tmp/converted.md

# Создание нового набора памяти для org-mode PKM
mkdir -p memory/org-mode-pkm/entities

# Структура файлов:
# memory/org-mode-pkm/user.md          - Профиль пользователя из org-файлов
# memory/org-mode-pkm/entities/*.md    - Сущности (проекты, люди, концепции)
# memory/org-mode-pkm/.org_sync_metadata.json - Метаданные синхронизации
```

### Продвинутая org-mode синхронизация
```bash
# Инкрементальное обновление (только измененные файлы)
make connect-memory CONNECTOR=org-mode SOURCE=/home/roman/org

# Пропуск существующих файлов
make connect-memory CONNECTOR=org-mode SOURCE=/home/roman/org --skip-existing

# Ограничение количества файлов
make connect-memory CONNECTOR=org-mode SOURCE=/home/roman/org MAX_ITEMS=50

# Автоматическая синхронизация через скрипт
./scripts/sync-org-pkm.sh                    # Базовая синхронизация
./scripts/sync-org-pkm.sh --max-files 50     # С ограничением
./scripts/sync-org-pkm.sh --skip-existing    # Пропуск существующих
./scripts/sync-org-pkm.sh --watch           # Мониторинг изменений (требует inotify-tools)
./scripts/sync-org-pkm.sh --dry-run         # Предварительный просмотр
```

### Возможности org-mode коннектора
- ✅ **Дедупликация по хешу**: Обработка только измененных файлов
- ✅ **Метаданные синхронизации**: Отслеживание состояния всех файлов  
- ✅ **Инкрементальные обновления**: Быстрая синхронизация больших PKM баз
- ✅ **Автоматический мониторинг**: Режим watch для непрерывной синхронизации
- ✅ **Умная классификация**: Автоопределение профилей пользователя и сущностей

## 📋 Подробные инструкции по org-mode интеграции

### Шаг 1: Проверка зависимостей
```bash
# Проверить наличие pandoc
pandoc --version

# Если нет - установить в NixOS:
nix-env -iA nixpkgs.pandoc
# Или добавить в configuration.nix: environment.systemPackages = [ pkgs.pandoc ];

# Проверить uv (уже должно быть установлено)
uv --version
```

### Шаг 2: Первичная настройка
```bash
# Создать директорию для org-mode памяти
mkdir -p memory/org-mode-pkm/entities

# Убедиться что org-файлы доступны
ls ~/org/*.org  # Должны быть видны ваши org-файлы
```

### Шаг 3: Тестовая синхронизация (один файл)
```bash
# Протестировать с одним файлом
make connect-memory CONNECTOR=org-mode SOURCE=~/org/about_me.org OUTPUT=memory/org-mode-pkm

# Проверить результат
ls memory/org-mode-pkm/
cat memory/org-mode-pkm/.org_sync_metadata.json
```

### Шаг 4: Полная синхронизация
```bash
# Вариант 1: Через make (с ограничением файлов для начала)
make connect-memory CONNECTOR=org-mode SOURCE=~/org MAX_ITEMS=50 OUTPUT=memory/org-mode-pkm

# Вариант 2: Через удобный скрипт
./scripts/sync-org-pkm.sh --max-files 50

# Полная синхронизация (осторожно - может быть много файлов!)
./scripts/sync-org-pkm.sh
```

### Шаг 5: Проверка результатов
```bash
# Статистика
ls memory/org-mode-pkm/entities/ | wc -l  # Количество сущностей
jq '.files | length' memory/org-mode-pkm/.org_sync_metadata.json  # Отслеживаемых файлов

# Тест с агентом
make chat-cli  # Спросить: "Расскажи о моих проектах из org-файлов"
```

### Шаг 6: Настройка автоматизации

#### Вариант А: Ручная синхронизация по требованию
```bash
# После изменения org-файлов запускать:
./scripts/sync-org-pkm.sh  # Быстро - обработает только измененные
```

#### Вариант Б: Автоматический мониторинг
```bash
# Установить inotify-tools для NixOS
nix-env -iA nixpkgs.inotify-tools

# Запустить мониторинг в отдельном терминале
./scripts/sync-org-pkm.sh --watch  # Синхронизация при каждом изменении .org файлов
```

#### Вариант В: Готовый NixOS модуль (РЕКОМЕНДУЕТСЯ)

**Используй готовый файл `romanos/hosts/thinkpad/services/org-sync.nix`:**

```bash
# 1. Добавить в твой configuration.nix
{
  imports = [
    ./hosts/thinkpad/services/org-sync.nix
  ];
}

# 2. Применить конфигурацию
sudo nixos-rebuild switch

# 3. Активировать user timer
systemctl --user enable org-sync.timer
systemctl --user start org-sync.timer
systemctl --user status org-sync.timer
```

**Возможности готового модуля:**
- 🔄 Автозапуск каждые 30 минут
- 📝 Подробное логирование в `/home/roman/logs/org-sync/`
- ⏰ Timeout защита (15 минут максимум)
- 🔒 Безопасная изоляция user service
- 📊 Ограничение файлов (100 за раз)
- 🧹 Автоочистка логов (7 дней)

**Управление:**
```bash
# Проверка статуса
systemctl --user status org-sync.timer
systemctl --user list-timers org-sync.timer

# Ручной запуск
systemctl --user start org-sync.service

# Логи
journalctl --user -u org-sync.service -f
tail -f /home/roman/logs/org-sync/org-sync-$(date +%Y-%m-%d).log

# Остановка
systemctl --user stop org-sync.timer
```

#### Вариант Г: Базовый systemd для экспериментов
Если хочешь создать свой минимальный вариант:

```nix
# В configuration.nix
{
  systemd.user.services.org-sync = {
    description = "Sync org-mode PKM to mem-agent";
    path = with pkgs; [ bash uv pandoc jq ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/home/roman/mem-agent-mcp/scripts/sync-org-pkm.sh --max-files 50";
      WorkingDirectory = "/home/roman/mem-agent-mcp";
      Environment = [
        "PATH=${lib.makeBinPath (with pkgs; [ bash uv pandoc jq ])}:/home/roman/.local/bin"
        "HOME=/home/roman"
      ];
    };
  };
  
  systemd.user.timers.org-sync = {
    description = "Sync org-mode PKM every 30 minutes";
    timerConfig = {
      OnCalendar = "*:0/30";
      Persistent = true;
      RandomizedDelaySec = "5min";
    };
    wantedBy = [ "timers.target" ];
  };
}
```

### Опции скрипта sync-org-pkm.sh

```bash
# Показать все опции
./scripts/sync-org-pkm.sh --help

# Основные команды:
./scripts/sync-org-pkm.sh                           # Базовая синхронизация
./scripts/sync-org-pkm.sh --max-files 50           # Ограничить количество файлов  
./scripts/sync-org-pkm.sh --skip-existing          # Пропустить существующие файлы
./scripts/sync-org-pkm.sh --dry-run                # Показать что будет сделано
./scripts/sync-org-pkm.sh --force                  # Принудительная полная синхронизация
./scripts/sync-org-pkm.sh --watch                  # Автоматический мониторинг
./scripts/sync-org-pkm.sh --org-dir /custom/path   # Кастомный путь к org-файлам
```

### Структура файлов после синхронизации
```
memory/org-mode-pkm/
├── user.md                              # Профиль пользователя
├── entities/                           # Сущности из org-файлов
│   ├── about_me.md                     # Материалы для интервью
│   ├── nixos.md                        # Документация по NixOS
│   ├── notes.md                        # Технические заметки
│   └── ...                             # Другие org-файлы
└── .org_sync_metadata.json             # Метаданные синхронизации (хеши, время)
```

### Troubleshooting

**Проблема**: "pandoc не найден"
```bash
# NixOS
nix-env -iA nixpkgs.pandoc
# Или в configuration.nix
```

**Проблема**: Слишком много файлов для обработки
```bash
# Использовать ограничение
./scripts/sync-org-pkm.sh --max-files 100
```

**Проблема**: Нужно полностью пересинхронизировать  
```bash
# Удалить метаданные и запустить заново
rm memory/org-mode-pkm/.org_sync_metadata.json
./scripts/sync-org-pkm.sh --force
```

**Проблема**: Режим --watch не работает
```bash
# Установить inotify-tools
nix-env -iA nixpkgs.inotify-tools
```

**Проблема**: "./scripts/sync-org-pkm.sh: bad interpreter: /bin/bash"
```bash
# В NixOS bash находится в другом месте - уже исправлено в скрипте
# Используется #!/usr/bin/env bash вместо #!/bin/bash
```

**Проблема**: "command not found" в cron/systemd
```bash
# Указать полные пути в NixOS или использовать systemd.user.services
# См. инструкции выше для правильной настройки systemd timer
```

### Настройка интеграции
```bash
make generate-mcp-json     # Генерировать конфигурацию MCP для Claude Desktop
make serve-mcp-http        # Запустить HTTP сервер совместимый с MCP для ChatGPT
```

### Примеры коннекторов памяти
```bash
# Экспорт ChatGPT
make connect-memory CONNECTOR=chatgpt SOURCE=/путь/к/export.zip

# Репозиторий GitHub
make connect-memory CONNECTOR=github SOURCE="владелец/репо" TOKEN=github_токен

# Папка Google Docs
make connect-memory CONNECTOR=google-docs SOURCE="id_папки" TOKEN=токен_доступа

# Экспорт Notion
make connect-memory CONNECTOR=notion SOURCE=/путь/к/export.zip
```

## Обзор архитектуры

### Основные компоненты

**Модуль агента (`agent/`):**
- `agent.py`: Основной класс Agent, который координирует поиск в памяти и взаимодействие с LLM
- `engine.py`: Движок выполнения кода в песочнице с ограничениями доступа к файлам
- `model.py`: Управление клиентами моделей (OpenAI, vLLM, MLX интеграция)
- `tools.py`: Определения инструментов для операций с памятью и управления файлами
- `utils.py`: Вспомогательные функции для управления памятью и форматирования ответов

**MCP Сервер (`mcp_server/`):**
- `server.py`: FastMCP сервер, предоставляющий инструменты памяти для Claude Desktop/Code
- `http_server.py`: HTTP обертка для интеграции с ChatGPT
- `mcp_http_server.py`: Реализация HTTP сервера совместимого с MCP
- `settings.py`: Управление конфигурацией для MCP сервера

**Коннекторы памяти (`memory_connectors/`):**
- `base.py`: Абстрактный базовый класс для всех коннекторов памяти
- `chatgpt_history/`: Обработка экспорта разговоров ChatGPT
- `github_live/`: Живая интеграция с репозиториями GitHub
- `google_docs_live/`: Живая интеграция с папками Google Docs
- `notion/`, `nuclino/`: Коннекторы на основе экспорта рабочих пространств
- `memory_wizard.py`: Интерактивный мастер настройки коннекторов

### Архитектура системы памяти

Система использует структуру памяти в стиле Obsidian:
```
memory/
├── user.md                    # Основной профиль пользователя со ссылками на сущности
└── entities/
    ├── [имя_сущности].md      # Индивидуальные файлы сущностей
    └── [тема]/                # Подкаталоги, организованные по темам
        └── conversations/     # Файлы разговоров
```

**Ключевые особенности:**
- Навигация через вики-ссылки: `[[entities/имя_сущности.md]]`
- Организация по темам с автоматической категоризацией
- Перекрестные ссылки между сущностями
- Оптимизирована для обнаружения и поиска агентом

### Интеграция с моделями

**Развертывание в зависимости от платформы:**
- **macOS**: MLX модели через LM Studio (4-bit, 8-bit, bf16 варианты)
- **Linux**: Развертывание vLLM сервера с GPU ускорением
- **NixOS**: LM Studio (рекомендуется) или OpenRouter API
- **Выбор модели**: семейство `driaforall/mem-agent`, оптимизированное для задач с памятью

**Поддержка клиентов:**
- Совместимость с OpenAI API для внешних моделей
- Интеграция с локальным vLLM сервером
- MLX локальный вывод на Apple Silicon
- LM Studio для кроссплатформенного использования

### Шаблоны интеграции MCP

**Claude Desktop/Code:**
- STDIO транспорт с фреймворком FastMCP
- Операции с памятью на основе инструментов
- Выполнение кода в песочнице для файловых операций

**Интеграция с ChatGPT:**
- HTTP сервер с конечными точками совместимыми с MCP
- Требует ngrok или аналогичное туннелирование для внешнего доступа
- Протокол JSON-RPC через HTTP

## Подробное руководство по установке и использованию

### Быстрый старт

**Шаг 1: Клонирование и установка**
```bash
git clone <repo-url>
cd mem-agent-mcp
make check-uv    # Установить uv если необходимо
make install     # Установить зависимости
```

**Шаг 2: Установка LM Studio (рекомендуется)**
```bash
# Скачайте LM Studio с https://lmstudio.ai
# После установки скачайте модель:
lms get driaforall/mem-agent
```

**Шаг 3: Настройка памяти**
```bash
# Автоматическая настройка (создает базовую структуру)
mkdir -p memory/mcp-server
echo "$(pwd)/memory/mcp-server" > .memory_path

# Или интерактивная настройка через GUI
make setup
```

**Шаг 4: Запуск системы**
```bash
# Запустить локальный агент
make run-agent

# В другом терминале: интерактивный чат
make chat-cli
```

### Интеграция с Claude Desktop

**Шаг 1: Генерация конфигурации**
```bash
make generate-mcp-json
```

**Шаг 2: Настройка Claude Desktop**
1. Найдите файл конфигурации Claude Desktop:
   - **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
   - **Linux**: `~/.config/claude/claude_desktop_config.json`
   - **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`

2. Скопируйте содержимое `mcp.json` в конфигурационный файл Claude Desktop
3. Перезапустите Claude Desktop

**Шаг 3: Тестирование**
```bash
# Убедитесь что агент запущен
make run-agent

# В Claude Desktop спросите: "Найди информацию в моей памяти о проекте mem-agent"
```

### Интеграция с Claude Code (рекомендуется)

**🚀 Полная интеграция с вашей PKM базой прямо в Claude Code!**

**Шаг 1: Установка Claude Code**
```bash
# Установить Claude Code из официального сайта: https://claude.ai/code
# После установки будет доступна команда `claude`
```

**Шаг 2: Подключение MCP сервера к Claude Code**
```bash
# 1. Убедиться, что находитесь в директории проекта
cd /home/roman/mem-agent-mcp

# 2. Добавить MCP сервер в Claude Code
claude mcp add memory-agent-stdio "bash -c 'cd /home/roman/mem-agent-mcp && uv run python mcp_server/server.py'"

# 3. Проверить подключение
claude mcp list
```

**Шаг 3: Использование**
```bash
# Интерактивный режим
claude

# Примеры вопросов:
"Найди мне информацию о NixOS из моих заметок"
"Что я писал про Python в org-файлах?"
"Покажи мои заметки о RAG системах"
```

**✨ Преимущества интеграции с Claude Code:**
- 🎯 **Прямой доступ к данным**: Поиск по всей вашей PKM базе
- 🤖 **Умный агент**: Memory agent анализирует контекст и находит релевантную информацию
- 🔄 **Автоматическая синхронизация**: org-mode файлы обновляются каждые 30 минут
- 💬 **Естественные вопросы**: Просто спрашивайте на обычном языке
- 📁 **Множественные источники**: ChatGPT истории, org-mode, GitHub и другие

**🔧 Отладка подключения:**
```bash
# Если MCP сервер не подключается:
# 1. Проверить что находитесь в правильной директории
pwd  # Должно быть /home/roman/mem-agent-mcp

# 2. Проверить что MCP сервер запускается вручную
uv run python mcp_server/server.py

# 3. Удалить и пересоздать подключение
claude mcp remove memory-agent-stdio
claude mcp add memory-agent-stdio "bash -c 'cd /home/roman/mem-agent-mcp && uv run python mcp_server/server.py'"

# 4. Проверить статус
claude mcp list
```

**📊 Доступные возможности через Claude Code:**
- `use_memory_agent` - главный инструмент для поиска в вашей базе знаний
- `get_size`, `read_file`, `list_files` - управление файлами памяти
- `go_to_link` - навигация по wikilink ссылкам
- `create_file`, `update_file` - создание новых заметок

### Интеграция с ChatGPT

**Альтернативный способ через HTTP API для ChatGPT Custom GPT**

**Шаг 1: Запуск HTTP сервера**
```bash
make serve-mcp-http  # Запускается на localhost:8081
```

**Шаг 2: Настройка туннеля (в другом терминале)**
```bash
# Установить ngrok: https://ngrok.com
ngrok http 8081
# Скопируйте HTTPS URL из вывода
```

**Шаг 3: Создание Custom GPT в ChatGPT**
1. Перейдите в ChatGPT и нажмите "Create a GPT"
2. В разделе **Actions** добавьте новый action:
   - **Authentication**: None
   - **Schema**: Импортируйте схему с вашего ngrok URL: `https://ваш-ngrok-url.ngrok.io/mcp/schema`
3. В **Instructions** добавьте:
   ```
   You are a personal knowledge assistant with access to the user's memory through MCP tools.
   Use the use_memory_agent tool to search and retrieve information from the user's knowledge base.
   The knowledge base contains org-mode notes, ChatGPT conversations, and other personal data.
   Always use the memory tools when the user asks about their notes, past conversations, or personal information.
   ```

**Шаг 4: Тестирование**
Спросите ваш Custom GPT: "Найди мои заметки о NixOS"

### Импорт данных

**Интерактивный мастер (рекомендуется):**
```bash
make memory-wizard
```

**Выбор папки вывода:**
При запуске мастера система предложит папку для сохранения импортированных данных:
- **Default**: `/путь/к/проекту/memory/mcp-server` ← **Рекомендуется нажать Enter**
- **Custom**: Ввести свой путь

**Структура множественных наборов памяти:**
```bash
memory/                    # Ваша основная память (профиль, проекты)
memory/mcp-server/         # Импортированные данные ChatGPT  
memories/healthcare/       # Примеры медицинских данных
memories/client_success/   # Примеры бизнес данных
```

**Переключение между наборами памяти:**
```bash
# Использовать свою основную память
echo "$(pwd)/memory" > .memory_path

# Переключиться на импортированные данные ChatGPT
echo "$(pwd)/memory/mcp-server" > .memory_path

# Протестировать медицинские примеры
echo "$(pwd)/memories/healthcare" > .memory_path

# Протестировать бизнес примеры  
echo "$(pwd)/memories/client_success" > .memory_path

# Проверить текущий набор
cat .memory_path
```

**Преимущества множественных наборов:**
- **🔒 Изоляция данных**: Каждый источник в отдельной папке
- **🔄 Легкое переключение**: Мгновенная смена контекста памяти
- **🧪 Тестирование**: Сравнение разных наборов данных
- **🛡️ Безопасность**: Основная память не перезаписывается
- **📊 Специализация**: Разные домены для разных задач

**Примеры импорта различных источников:**

**ChatGPT экспорт:**
```bash
# 1. Экспортируйте данные из ChatGPT:
#    - Перейдите в Настройки → Управление данными
#    - Нажмите "Экспорт данных"
#    - Дождитесь ссылки на скачивание по почте (может занять до 24 часов)

# 2. Импортируйте данные через мастер:
make memory-wizard
# Выберите: 1 (ChatGPT History)
# Нажмите Enter для default папки
# Укажите путь к скачанному ZIP файлу
# Выберите метод обработки (рекомендуется Nomic Embed для качества)

# 3. Альтернативный способ через CLI:
make connect-memory CONNECTOR=chatgpt SOURCE=/путь/к/chatgpt-export.zip
```

**Результат импорта ChatGPT:**
- 🧠 **AI-категоризация**: Автоматическое обнаружение тематических кластеров
- 📊 **Статистика**: Показывает количество разговоров по темам
- 🔗 **Связи**: Создает wikilink навигацию между файлами
- 📝 **Читаемые названия**: Генерирует понятные названия для разговоров
- 🎯 **Семантический поиск**: Находит связанные обсуждения по смыслу

**Пример результата:**
```
memory/mcp-server/
├── user.md                           # Ваш профиль и стиль общения
└── entities/chatgpt-history/
    ├── index.md                      # Обзор всех импортированных данных
    ├── topics/                       # Темы, найденные AI
    │   ├── programming.md            # 332 разговора про программирование
    │   ├── arch.md                   # 45 разговоров про Arch Linux
    │   └── emacs.md                  # 24 разговора про Emacs
    └── conversations/                # Отдельные файлы разговоров
        ├── conv_001_nixos_setup.md   # Настройка NixOS окружения
        └── conv_002_python_basics.md # Основы Python
```

**GitHub репозиторий:**
```bash
# 1. Получите токен: https://github.com/settings/tokens
#    Права: public_repo (для публичных) или repo (для приватных)

# 2. Импортируйте репозиторий:
make connect-memory CONNECTOR=github SOURCE="владелец/репо" TOKEN=ваш_токен
```

**Notion экспорт:**
```bash
# 1. В Notion: Настройки → Экспорт → Экспортировать все содержимое
#    Формат: Markdown & CSV

# 2. Импортируйте данные:
make connect-memory CONNECTOR=notion SOURCE=/путь/к/notion-export.zip
```

### Настройка фильтров приватности

```bash
# Добавить фильтры (интерактивно)
make add-filters

# Примеры фильтров:
# - Не раскрывать точные возрасты
# - Не показывать email адреса
# - Скрыть финансовую информацию

# Сбросить фильтры
make reset-filters
```

### Тестирование с примерными данными

Система включает готовые примеры памяти:

**Медицинский домен:**
```bash
# Переключиться на пример медицинских данных
echo "$(pwd)/memories/healthcare" > .memory_path
make chat-cli
# Спросите: "Расскажи о пациенте Джеймсе Ривера"
```

**Бизнес домен:**
```bash
# Переключиться на пример бизнес данных
echo "$(pwd)/memories/client_success" > .memory_path
make chat-cli
# Спросите: "Какая стратегия обновления для OrbitBank?"
```

### Практические сценарии использования множественных наборов

**Сценарий 1: Разработчик с множественными проектами**
```bash
# Утром: работа над проектом A
echo "$(pwd)/memory/project-a" > .memory_path
# Вечером: личные заметки и ChatGPT истории
echo "$(pwd)/memory/personal" > .memory_path
```

**Сценарий 2: Исследователь с доменной специализацией**
```bash
# Медицинские исследования
echo "$(pwd)/memories/healthcare" > .memory_path
# Технические обсуждения
echo "$(pwd)/memory/chatgpt-tech" > .memory_path
# Бизнес анализ
echo "$(pwd)/memories/client_success" > .memory_path
```

**Сценарий 3: Тестирование и отладка**
```bash
# Тестовые данные
echo "$(pwd)/memory/test-data" > .memory_path
# Продакшн память
echo "$(pwd)/memory/production" > .memory_path
# Резервная копия
echo "$(pwd)/memory/backup" > .memory_path
```

## 🎉 Итоговые достижения проекта

### ✅ Claude Code интеграция (ЗАВЕРШЕНА)
- 🔗 **MCP сервер подключен**: `memory-agent-stdio` успешно интегрирован в Claude Code
- 🤖 **Memory Agent доступен**: инструмент `use_memory_agent` работает корректно  
- 🔍 **Поиск работает**: Claude Code может находить информацию во всей базе знаний
- 💬 **Естественные запросы**: просто спрашивайте "Найди мне..." без технических команд
- ⚡ **Быстрый доступ**: мгновенный поиск по org-mode файлам, ChatGPT истории и других источниках

### ✅ org-mode PKM система (ЗАВЕРШЕНА)  
- 🔄 **Автоматическая синхронизация**: NixOS systemd.user.timer каждые 30 минут
- 📊 **Дедупликация SHA256**: обработка только измененных файлов
- ⚡ **Инкрементальные обновления**: секунды вместо минут для больших баз
- 🛠️ **Готовый NixOS модуль**: `romanos/hosts/thinkpad/services/org-sync.nix`
- 📝 **Подробные логи**: `/home/roman/logs/org-sync/` с ротацией
- 🔒 **Безопасность**: изолированный user service

### ✅ Полная интеграция экосистемы
- 📱 **Claude Code**: основной интерфейс для работы с памятью
- 🌐 **ChatGPT Custom GPT**: альтернативный доступ через HTTP API
- 📋 **org-mode синхронизация**: автоматическое обновление PKM заметок
- 🧠 **Memory Agent**: умный поиск и анализ всех данных
- 🔄 **Множественные источники**: ChatGPT, org-mode, GitHub, Notion и другие

### 🚀 Практические результаты
**Реальные данные пользователя Рома:**
- 📊 **484 ChatGPT разговора** импортированы и проиндексированы
- 📊 **6 тематических кластеров** найдены автоматически  
- 📊 **org-mode файлы** синхронизируются автоматически
- 🔍 **Семантический поиск** находит релевантную информацию
- 🇷🇺 **Русский язык** полностью поддерживается

**Примеры работающих запросов:**
```
"Найди мне упоминание о том, что я хотел сделать форк репозитория на GitHub"
"Что я писал о NixOS в своих заметках?"
"Покажи мои обсуждения про Python из ChatGPT"
"Расскажи о моих проектах из org-файлов"
```

### 🎯 Готовность к продакшену
- ✅ **Стабильная работа**: протестировано на реальных данных
- ✅ **Автоматизация**: полностью автономная система
- ✅ **Документация**: подробные инструкции на русском языке
- ✅ **Отладка**: детальные инструкции по решению проблем
- ✅ **Масштабируемость**: готова для больших объемов данных

## ✅ Достижения и подтвержденная функциональность

### 🎯 Успешно протестировано на NixOS
- ✅ **LM Studio интеграция**: Автоматическое определение и использование
- ✅ **Модель mem-agent**: Загружена и работает (4B параметров, 2.38 ГБ)
- ✅ **ChatGPT импорт**: 484 разговора успешно импортированы и категоризированы
- ✅ **AI-категоризация**: Найдено 6 тематических кластеров автоматически
- ✅ **Семантический поиск**: Поиск по смыслу, а не только ключевым словам
- ✅ **Русская локализация**: Полная поддержка русского языка в ответах
- ✅ **org-mode интеграция**: Полная PKM система с инкрементальными обновлениями

### 🚀 Реальные результаты тестирования
**Импорт данных пользователя Рома:**
- 📊 **332 разговора** про программирование (NixOS, Python, LaTeX)
- 📊 **45 разговоров** про Arch Linux
- 📊 **43 разговора** категории "Как" (инструкции и вопросы)
- 📊 **30 разговоров** про ЧПУ станки
- 📊 **24 разговора** про Emacs редактор
- 📊 **10 разговоров** про видео контент

### 🔧 Новые возможности org-mode интеграции
**Полная PKM система с инкрементальными обновлениями:**
- 📦 **Custom org-mode коннектор**: `/memory_connectors/org_mode/`
- 🔄 **Дедупликация SHA256**: Обработка только измененных файлов  
- 📊 **Метаданные синхронизации**: `.org_sync_metadata.json` отслеживает состояние
- ⚡ **Инкрементальные обновления**: Секунды вместо минут при больших PKM базах
- 🎯 **Умная классификация**: Автоопределение профилей vs сущностей по содержимому
- 🛠️ **Скрипт автоматизации**: `scripts/sync-org-pkm.sh` с опциями watch/dry-run/force
- 🔗 **Интеграция с Makefile**: `make connect-memory CONNECTOR=org-mode`
- 📋 **Опция --skip-existing**: Пропуск файлов с существующими выходными файлами

**Качество AI-анализа:**
- 🎯 Точно определил профиль: "Рома из компании Dria"
- 🎯 Выявил стиль общения: прямой, практичный, инновационный
- 🎯 Создал осмысленные категории с понятными названиями
- 🎯 Связал похожие обсуждения через wikilink навигацию

### 🧪 Примеры успешных запросов
```bash
# Переключиться на ChatGPT память
echo "$(pwd)/memory/mcp-server" > .memory_path
make chat-cli

# Примеры запросов которые работают:
"Расскажи о моих разговорах про программирование"
"Что я обсуждал про NixOS?"
"Покажи мои вопросы про Python"
"Какие проблемы я решал с Emacs?"
```

### Решение проблем

**vLLM не работает на NixOS:**
- ✅ **Решено**: Используйте LM Studio (`lms get driaforall/mem-agent`)
- ✅ Система автоматически определит LM Studio и использует его
- ✅ Никаких проблем с CUDA совместимостью

**Модель не найдена:**
```bash
# Проверить доступные модели
lms ls

# Скачать модель mem-agent
lms get driaforall/mem-agent
```

**Несколько экземпляров модели:**
```bash
# Проверить загруженные модели
lms ps

# Выгрузить ненужные экземпляры
lms unload driaforall.mem-agent    # Выгрузить первый экземпляр
lms unload driaforall.mem-agent:2  # Выгрузить второй экземпляр

# Загрузить модель заново
lms load driaforall.mem-agent
```

**MCP сервер не подключается:**
```bash
# Проверить что агент запущен
curl http://localhost:8000/v1/models

# Перегенерировать конфигурацию
make generate-mcp-json
```

**Проблемы с памятью:**
```bash
# Проверить путь к памяти
cat .memory_path

# Создать базовую структуру памяти
mkdir -p memory/mcp-server/entities
echo "# Пользователь\n- имя: Тестовый пользователь" > memory/mcp-server/user.md
```

**Проблемы с ChatGPT импортом:**
```bash
# Если ZIP архив не распознается
mkdir -p /tmp/chatgpt-extract
cd /tmp/chatgpt-extract
unzip /путь/к/chatgpt-export.zip

# Импорт из извлеченной директории
uv run python -m memory_connectors.memory_connect chatgpt /tmp/chatgpt-extract --method ai --embedding-model tfidf --output memory/mcp-server --max-items 10

# Если отсутствует scikit-learn для TF-IDF
uv add scikit-learn
```

**Проблемы с памятью при больших импортах:**
```bash
# Ограничить количество разговоров для тестирования
make memory-wizard
# При выборе параметров укажите max-items: 50

# Или через CLI
uv run python -m memory_connectors.memory_connect chatgpt /путь/к/архиву --max-items 50
```

## 📚 История изменений и улучшений

### Версия 2.0 (Текущая) - Полная NixOS поддержка
**✅ Достижения:**
- 🔧 **NixOS автоопределение**: Система автоматически определяет NixOS и предлагает LM Studio
- 🧠 **LM Studio интеграция**: Бесшовная работа с локальными моделями
- 🤖 **ChatGPT импорт**: Полный цикл от экспорта до семантического поиска
- 🌐 **AI-категоризация**: TF-IDF и Nomic Embed методы обработки
- 🇷🇺 **Русская локализация**: Полная документация и интерфейс на русском
- 📊 **Множественные наборы**: Легкое переключение между источниками памяти

**🛠️ Технические улучшения:**
- Исправлена совместимость vLLM с NixOS
- Добавлена поддержка scikit-learn для TF-IDF
- Оптимизирован парсер ChatGPT архивов
- Улучшена обработка больших объемов данных
- Добавлены детальные инструкции по отладке

**🎯 Проверенная функциональность:**
- ✅ Импорт 484 реальных разговоров ChatGPT
- ✅ AI-обнаружение 6 тематических кластеров
- ✅ Семантический поиск по содержимому
- ✅ Автоматическая генерация wikilink навигации
- ✅ Поддержка русского языка в ответах агента

### Разработка коннекторов памяти

При добавлении новых коннекторов наследуйтесь от `BaseMemoryConnector` и реализуйте:
- `extract_data()`: Разбор формата исходных данных
- `organize_data()`: Категоризация по темам и сущностям
- `generate_memory_files()`: Создание markdown файлов с правильными ссылками

### Файлы конфигурации

- `.memory_path`: Абсолютный путь к директории памяти
- `.filters`: Фильтры приватности применяемые к запросам
- `.mlx_model_name`: Выбранный вариант MLX модели (macOS)
- `mcp.json`: Сгенерированная конфигурация MCP сервера

### Частые задачи разработки

**Запуск тестов:**
```bash
# Тесты модуля агента
cd agent && uv run pytest

# Тесты MCP сервера
cd mcp_server && uv run pytest
```

**Режим разработки:**
```bash
# Установка в режиме разработки
uv sync

# Запуск с отладочным логированием
FASTMCP_LOG_LEVEL=DEBUG make serve-mcp
```