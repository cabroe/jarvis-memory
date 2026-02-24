---
name: jarvis-memory
description: Store and retrieve agent memory using local Jarvis Memory API. Semantic search, confidence scoring, memory decay, and full CRUD for persistent agent memory.
user-invocable: true
metadata: {"openclaw": {"emoji": "🧠"}}
---

# 🧠 Jarvis Memory

Persistent memory storage with semantic search, confidence scoring, and memory decay for AI agents. Save text as seeds, search semantically, manage memory quality, and persist agent context between sessions — entirely locally.

## ✨ Features

- 🔍 **Semantic Search** — Find memories by meaning (GTE-Small, 384 dimensions, pgvector HNSW)
- 🎯 **Confidence Scoring** — Each seed has a weight (0.0–1.0) that influences search ranking
- 📉 **Memory Decay** — Old, low-confidence seeds automatically lose relevance
- ✏️ **Full CRUD** — Create, update, and delete seeds via CLI or REST API
- 🔄 **Auto-Recall** — Queries relevant memories before each AI turn and injects as context
- 💾 **Auto-Capture** — Saves conversations after each AI turn (Dual Storage: Seed + Context)
- 🔒 **100% Local** — No API keys, no external services, complete privacy

## Prerequisites

The API runs as a Docker container. Ensure it's running:

```bash
cd /home/jarvis/jarvis-memory
docker compose up -d
```

The API is available at `http://localhost:8080`. No API keys or authentication required.

## Testing

```bash
./scripts/jarvis-memory.sh test
```

## Hooks (Auto-Capture & Auto-Recall)

- `hooks/pre-tool-use.sh` — 🔍 **Auto-Recall**: Queries memories before AI turn, injects relevant context
- `hooks/post-tool-use.sh` — 💾 **Auto-Capture**: Saves conversation as Seed (Thread Snapshot) + Agent Context

### Configuration

Both features are **enabled by default**. To disable:

```bash
export JARVIS_AUTO_RECALL=false
export JARVIS_AUTO_CAPTURE=false
```

## CLI Commands

```bash
./scripts/jarvis-memory.sh <command> [args]
```

### 🌱 Seeds

```bash
# 💾 Save a memory
./scripts/jarvis-memory.sh save "Content to remember" "Title" [type]

# 🔍 Semantic search
./scripts/jarvis-memory.sh search "query text" [limit] [threshold]

# � Time-based search
./scripts/jarvis-memory.sh search "Was ist passiert?" --since today
./scripts/jarvis-memory.sh search "Was war letzte Woche?" --since last_week --until this_week
./scripts/jarvis-memory.sh search "JARVIS" --since 2026-02-20
# Keywords: today, yesterday, this_week, last_week, this_month, last_month, YYYY-MM-DD

# �📋 List latest seeds
./scripts/jarvis-memory.sh list [limit]

# ✏️ Update a seed
./scripts/jarvis-memory.sh update <UUID> "New content" "New title" [type]

# 🗑️ Delete a seed
./scripts/jarvis-memory.sh delete <UUID>

# ⚖️ Set confidence (0.0-1.0)
./scripts/jarvis-memory.sh confidence <UUID> 0.5

# 📊 Show statistics
./scripts/jarvis-memory.sh stats
```

### 🤖 Agent Contexts

Agent-Contexts sind **zustandsbasierte Sitzungen** — nutze sie für eigene Erinnerungen und Zustände:

```bash
# Eigenen Status speichern
./scripts/jarvis-memory.sh context-create "JARVIS" "episodic" '{"status":"aktiv"}' "Ich bin online"

# Auflisten
./scripts/jarvis-memory.sh context-list "JARVIS"

# Einzelnen Context abrufen
./scripts/jarvis-memory.sh context-get <UUID>
```

**Nutzung:**
- Aktueller Status (online/offline)
- Emotionales Befinden
- Aktive Projekte
- Laufende Missionen

## 🎯 Confidence & Decay

Each seed has a **confidence** value (default `1.0`). Search results are weighted:

```
weighted_similarity = cosine_similarity × confidence
```

**Automatic Decay (Startup):**
- Beim Server-Start werden alle Seeds geprüft
- **Bedingung:** >90 Tage alt UND Confidence < 0.3
- **Aktion:** Confidence wird um 10% reduziert
- **Floor:** Confidence geht nie unter 0.01

**Last Accessed:**
- Jede Suche aktualisiert `last_accessed`
- Ermöglicht nutzungsbasiertes Vergessen

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/seeds` | 📋 List seeds (`?limit=N`) |
| `POST` | `/seeds` | 💾 Save text (multipart: `content`, `title`, `type`) |
| `POST` | `/seeds/query` | 🔍 Semantic search (JSON: `query`, `limit`, `threshold`) |
| `PUT` | `/seeds/:id` | ✏️ Update seed (JSON: `content`, `title`, `type`) |
| `DELETE` | `/seeds/:id` | 🗑️ Delete a seed |
| `POST` | `/seeds/:id/confidence` | ⚖️ Set confidence (JSON: `confidence`) |
| `POST` | `/agent-contexts` | 📝 Create agent context |
| `GET` | `/agent-contexts` | 📋 List contexts (`?agentId=` filter) |
| `GET` | `/agent-contexts/:id` | 🔎 Get specific context |

**Base URL:** `http://localhost:8080`
**Auth:** None required.

**Memory types:** `episodic`, `semantic`, `procedural`, `working`
**Seed content types:** `text`, `markdown`, `json`, `csv`, `auto_capture`
