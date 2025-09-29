#!/bin/bash
# sync-org-pkm.sh - Синхронизация org-mode PKM с памятью агента
# 
# Этот скрипт обеспечивает автоматическую синхронизацию org-mode файлов
# с системой памяти mem-agent-mcp, используя инкрементальные обновления.

set -e

# Настройки по умолчанию
DEFAULT_ORG_DIR="${HOME}/org"
DEFAULT_MEMORY_DIR="memory/org-mode-pkm"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для красивого вывода
log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}❌ Ошибка:${NC} $1" >&2
}

success() {
    echo -e "${GREEN}✅${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

# Показать справку
show_help() {
    cat << EOF
sync-org-pkm.sh - Синхронизация org-mode PKM с памятью агента

ИСПОЛЬЗОВАНИЕ:
    $0 [ОПЦИИ]

ОПЦИИ:
    --org-dir PATH          Путь к директории org-файлов (по умолчанию: ~/org)
    --memory-dir PATH       Путь к директории памяти (по умолчанию: memory/org-mode-pkm)
    --max-files N           Максимальное количество файлов для обработки
    --skip-existing         Пропускать файлы с существующими выходными файлами
    --watch                 Режим мониторинга изменений (экспериментальный)
    --dry-run               Показать что будет синхронизировано, но не выполнять
    --force                 Принудительная полная синхронизация (игнорировать хеши)
    --help, -h              Показать эту справку

ПРИМЕРЫ:
    # Базовая синхронизация
    $0

    # Синхронизация с ограничением количества файлов
    $0 --max-files 50

    # Синхронизация с пропуском существующих файлов
    $0 --skip-existing

    # Кастомные пути
    $0 --org-dir /path/to/org --memory-dir memory/custom-pkm

    # Режим мониторинга (требует inotify-tools)
    $0 --watch

ФАЙЛЫ:
    .org_sync_metadata.json - Метаданные синхронизации (хеши, время изменения)
    
ЗАВИСИМОСТИ:
    - pandoc (для конвертации org → markdown)
    - uv (для запуска Python)
    - inotify-tools (для режима --watch, опционально)

EOF
}

# Проверка зависимостей
check_dependencies() {
    local missing=0
    
    if ! command -v pandoc >/dev/null 2>&1; then
        error "pandoc не найден. Установите: apt install pandoc или подобное"
        missing=1
    fi
    
    if ! command -v uv >/dev/null 2>&1; then
        error "uv не найден. Установите: curl -LsSf https://astral.sh/uv/install.sh | sh"
        missing=1
    fi
    
    if [[ "$WATCH_MODE" == "true" ]] && ! command -v inotifywait >/dev/null 2>&1; then
        error "inotifywait не найден для режима --watch. Установите: apt install inotify-tools"
        missing=1
    fi
    
    if [[ $missing -eq 1 ]]; then
        exit 1
    fi
}

# Парсинг аргументов
parse_args() {
    ORG_DIR="$DEFAULT_ORG_DIR"
    MEMORY_DIR="$DEFAULT_MEMORY_DIR"
    MAX_FILES=""
    SKIP_EXISTING=""
    WATCH_MODE="false"
    DRY_RUN="false"
    FORCE="false"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --org-dir)
                ORG_DIR="$2"
                shift 2
                ;;
            --memory-dir)
                MEMORY_DIR="$2"
                shift 2
                ;;
            --max-files)
                MAX_FILES="$2"
                shift 2
                ;;
            --skip-existing)
                SKIP_EXISTING="--skip-existing"
                shift
                ;;
            --watch)
                WATCH_MODE="true"
                shift
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --force)
                FORCE="true"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                error "Неизвестная опция: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Выполнение синхронизации
do_sync() {
    local org_path="$1"
    local memory_path="$2"
    local extra_args="$3"
    
    log "Запуск синхронизации org-mode PKM"
    log "  Источник: $org_path"
    log "  Память: $memory_path"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "🧪 Режим DRY-RUN - команда будет:"
        echo "    cd \"$PROJECT_DIR\" && uv run python -m memory_connectors.memory_connect org-mode \"$org_path\" --output \"$memory_path\" $extra_args"
        return 0
    fi
    
    if [[ "$FORCE" == "true" ]]; then
        warning "Принудительная синхронизация - удаляю метаданные"
        rm -f "$memory_path/.org_sync_metadata.json"
    fi
    
    # Переходим в директорию проекта и запускаем синхронизацию
    cd "$PROJECT_DIR"
    
    local cmd="uv run python -m memory_connectors.memory_connect org-mode \"$org_path\" --output \"$memory_path\""
    
    if [[ -n "$MAX_FILES" ]]; then
        cmd="$cmd --max-items $MAX_FILES"
    fi
    
    if [[ -n "$SKIP_EXISTING" ]]; then
        cmd="$cmd $SKIP_EXISTING"
    fi
    
    log "Выполняю: $cmd"
    eval "$cmd"
    
    if [[ $? -eq 0 ]]; then
        success "Синхронизация завершена успешно"
        
        # Показываем статистику
        if [[ -f "$memory_path/.org_sync_metadata.json" ]]; then
            local file_count=$(jq -r '.files | length' "$memory_path/.org_sync_metadata.json" 2>/dev/null || echo "?")
            local last_sync=$(jq -r '.last_sync' "$memory_path/.org_sync_metadata.json" 2>/dev/null || echo "неизвестно")
            log "📊 Отслеживается файлов: $file_count, последняя синхронизация: $last_sync"
        fi
    else
        error "Синхронизация завершилась с ошибкой"
        exit 1
    fi
}

# Режим мониторинга изменений
watch_mode() {
    local org_path="$1"
    local memory_path="$2"
    local extra_args="$3"
    
    log "🔍 Запуск режима мониторинга изменений"
    log "  Отслеживаю: $org_path"
    warning "Для выхода нажмите Ctrl+C"
    
    # Первоначальная синхронизация
    do_sync "$org_path" "$memory_path" "$extra_args"
    
    # Мониторинг изменений
    inotifywait -m -r -e modify,create,delete,move --format '%w%f %e' "$org_path" 2>/dev/null | \
    while read file event; do
        # Проверяем, что это .org файл
        if [[ "$file" =~ \.org$ ]]; then
            log "📝 Обнаружено изменение: $file ($event)"
            
            # Небольшая задержка, чтобы файл успел полностью записаться
            sleep 1
            
            # Запускаем синхронизацию
            do_sync "$org_path" "$memory_path" "$extra_args"
        fi
    done
}

# Главная функция
main() {
    parse_args "$@"
    
    # Проверяем существование org директории
    if [[ ! -d "$ORG_DIR" ]]; then
        error "Директория org-файлов не найдена: $ORG_DIR"
        exit 1
    fi
    
    # Преобразуем пути в абсолютные
    ORG_DIR="$(readlink -f "$ORG_DIR")"
    
    # Для memory_dir - если путь относительный, делаем его относительно PROJECT_DIR
    if [[ "$MEMORY_DIR" != /* ]]; then
        MEMORY_DIR="$PROJECT_DIR/$MEMORY_DIR"
    fi
    
    check_dependencies
    
    local extra_args=""
    if [[ -n "$SKIP_EXISTING" ]]; then
        extra_args="$SKIP_EXISTING"
    fi
    
    if [[ "$WATCH_MODE" == "true" ]]; then
        watch_mode "$ORG_DIR" "$MEMORY_DIR" "$extra_args"
    else
        do_sync "$ORG_DIR" "$MEMORY_DIR" "$extra_args"
    fi
}

# Обработка сигналов для graceful shutdown
trap 'echo -e "\n🛑 Получен сигнал завершения, выходим..."; exit 0' INT TERM

# Запуск основной функции
main "$@"