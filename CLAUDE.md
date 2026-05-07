# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Docker wrapper for `translatorFork_MOD` — a PyQt6-based GUI application for translating EPUB books and documents using multiple AI providers (Google Gemini, Deepseek, OpenRouter, Ollama, ChatGPT Web, etc.). The container runs the GUI headlessly and exposes it via VNC on port 10000.

The main application source lives in `GeminiTranslator/` (a submodule/fork of the upstream project). The Docker layer (`Dockerfile`, `docker-compose.yaml`, `entrypoint.sh`, `supervisord.conf`) wraps it for headless deployment.

## Docker Commands

```bash
# Build the image
docker compose build --no-cache

# Start (background)
docker compose up -d

# Stop and remove containers
docker compose down

# Restart
docker compose restart

# Shell into running container
docker compose exec gemini-translator bash

# View logs
docker compose logs -f
```

## Running the Application Directly (without Docker)

```bash
cd GeminiTranslator
chmod +x run.sh
./run.sh   # Creates .venv, installs deps, launches main.py
```

## Testing

Tests live in `GeminiTranslator/tests/`. There is no test runner configuration; run individual test files directly:

```bash
cd GeminiTranslator
python -m pytest tests/
# or a single file:
python tests/test_glossary.py
```

No linting configuration exists in the repo.

## Architecture

### Deployment Layer (repo root)
- `Dockerfile` — Python 3.11-slim-bookworm; installs X11, Xvfb, Fluxbox, x11vnc, supervisor, CJK fonts, then Python deps from `requirements.txt`
- `entrypoint.sh` — initializes the X11 display and starts supervisord
- `supervisord.conf` — manages 4 processes: Xvfb (display `:1`), Fluxbox (window manager), x11vnc (VNC on port 10000), and the Python app
- `docker-compose.yaml` — single service `gemini-translator`; maps port 10000 for VNC, mounts `share/` and `epub_translator/` volumes
- `.env` — `VNC_PASSWORD` and `APP_DIR` (defaults to `GeminiTranslator`)

### Application Layer (`GeminiTranslator/`)

The app is structured in layers:

**Entry point:** `main.py` — launches the PyQt6 app; shows a startup dialog to select the active tool (Translator, Validator, Glossary Manager, Uploader)

**Core package:** `gemini_translator/`

| Sub-package | Responsibility |
|---|---|
| `core/` | `TranslationEngine` orchestrates translation; `ChapterQueueManager` manages the chapter queue; `WorkerThread` handles async API calls; `ConsistencyEngine` post-processes for terminology uniformity |
| `api/` | Pluggable provider system — `factory.py` creates handler instances; `config.py` loads `api_providers.json`; handlers in `api/handlers/` implement per-provider logic (Gemini, Deepseek, etc.) |
| `ui/` | PyQt6 windows and dialogs — `dialogs/` contains the main tool windows; `widgets/` has reusable components; `themes.py` provides dark-mode styling |
| `utils/` | File I/O (`epub_tools.py`, `document_importer.py`), settings, project lifecycle, glossary utilities, proxy support |

**Configuration:** `config/api_providers.json` defines all supported AI providers and their models. Adding a new provider requires an entry here and a handler in `api/handlers/`.

**Key data flow for translation:**
1. User opens an EPUB project → `ProjectManager` loads it
2. Chapters are queued in `ChapterQueueManager`
3. `WorkerThread` calls `TranslationEngine` which sends requests via the selected `ApiHandler`
4. Large chapters are split by `ChunkAssembler` and reassembled after translation
5. Optional: `ConsistencyEngine` and `GlossaryPipeline` post-process results

**Persistence:** Application state, project history, and queue snapshots are saved to `~/.epub_translator/` (mounted as `epub_translator/` volume in Docker).

**Shared files:** The `share/` directory is mounted at `/share` in the container — use it to pass EPUB files in/out.
