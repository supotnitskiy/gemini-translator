#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# update.sh — автообновление GeminiTranslator из GitHub релиза
# ============================================================
# 1. Определяет тег последнего релиза через GitHub API
#    (Rasteo123/translatorFork_MOD)
# 2. Останавливает контейнер (если запущен)
# 3. Сохраняет config/api_providers.json (страховка)
# 4. Скачивает Source code (zip) последнего релиза
# 5. Удаляет старую GeminiTranslator/ и распаковывает новую
# 6. Собирает и запускает контейнер
# ============================================================

PROJECT_DIR="/opt/gemini-translator"
LOG_FILE="/tmp/gemini-translator-update.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

log() {
    echo "[${TIMESTAMP}] $*" | tee -a "$LOG_FILE"
}

cd "$PROJECT_DIR"

# --- 1. Тег последнего релиза ---
log "Запрос последнего релиза с GitHub API..."
REPO="Rasteo123/translatorFork_MOD"
RELEASE_JSON=$(curl -sSf "https://api.github.com/repos/${REPO}/releases/latest" \
    -H "Accept: application/vnd.github+json")

TAG=$(echo "$RELEASE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])")
log "Последний тег: ${TAG} (источник: ${REPO})"

ZIP_URL="https://github.com/${REPO}/archive/refs/tags/${TAG}.zip"
ZIP_FILE="/tmp/translatorFork_MOD-${TAG}.zip"
EXTRACTED_DIR="translatorFork_MOD-${TAG#v}"   # архив распаковывается в translatorFork_MOD-10.5.22 (без 'v')

# --- 2. Остановка контейнера ---
if docker compose ps --status running 2>/dev/null | grep -q .; then
    log "Остановка контейнера..."
    docker compose down
    log "Контейнер остановлен"
else
    log "Контейнер не запущен — пропускаем остановку"
fi

# --- 3. Страховочная копия api_providers.json ---
CONFIG_FILE="GeminiTranslator/config/api_providers.json"
BACKUP_FILE="/tmp/api_providers.json.backup.$(date '+%Y%m%d_%H%M%S')"

if [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" "$BACKUP_FILE"
    log "Сохранён бэкап: ${BACKUP_FILE}"
else
    log "ВНИМАНИЕ: ${CONFIG_FILE} не найден — бэкап пропущен"
fi

# --- 4. Скачивание релиза ---
log "Скачивание ${ZIP_URL}..."
curl -sSfL -o "$ZIP_FILE" "$ZIP_URL"
log "Скачано: $(du -h "$ZIP_FILE" | cut -f1)"

# --- 5. Замена GeminiTranslator/ ---
log "Удаление старой GeminiTranslator/..."
rm -rf GeminiTranslator

log "Распаковка архива..."
unzip -qo "$ZIP_FILE"

if [ ! -d "$EXTRACTED_DIR" ]; then
    log "ОШИБКА: папка ${EXTRACTED_DIR} не найдена после распаковки"
    ls -la
    exit 1
fi

mv "$EXTRACTED_DIR" GeminiTranslator
log "Новая GeminiTranslator/ установлена (тег: ${TAG})"

# Очистка
rm -f "$ZIP_FILE"

# --- 6. Сборка и запуск ---
log "Сборка Docker-образа..."
docker compose build --no-cache 2>&1 | tee -a "$LOG_FILE"
log "Сборка завершена"

log "Запуск контейнера..."
docker compose up -d

log "ГОТОВО. Контейнер запущен, тег: ${TAG}"
log "Бэкап api_providers.json: ${BACKUP_FILE}"
