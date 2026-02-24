---
name: jarvis-memory
description: Store and retrieve agent memory using local Jarvis Memory API. Use for saving information with semantic search, and persisting agent context between sessions.
user-invocable: true
metadata: {"openclaw": {"emoji": "🧠"}}
---

# Jarvis Memory

Persistent memory storage with semantic search for AI agents. Save text as seeds, search semantically, and persist agent context between sessions entirely locally.

## Features

- **Auto-Recall**: Automatically queries relevant memories before each AI turn and injects as context
- **Auto-Capture**: Automatically saves conversations after each AI turn
- **Semantic Search**: Find memories by meaning using local GTE-Small Embeddings (384 dimensions)
- **Memory Types**: Episodic, semantic, procedural, and working memory
- **100% Local**: No API keys, no external services, complete privacy.

## Prerequisites

The API runs independently as a Docker container.

Ensure it's running:
```bash
cd /home/jarvis/jarvis-memory
docker compose up -d
```
The API is available at `http://localhost:8080`. No API keys or authentication are required.

## Testing

Verify your setup by hitting the admin dashboard in your browser:
**http://localhost:8080/admin**

You can also run a quick connection test:
```bash
./scripts/jarvis-memory.sh test
```

## Hooks (Auto-Capture & Auto-Recall)

The skill includes OpenClaw hooks for automatic memory management:

- `hooks/pre-tool-use.sh` - **Auto-Recall**: Queries memories before AI turn, injects relevant context
- `hooks/post-tool-use.sh` - **Auto-Capture**: Saves conversation after AI turn

### Configuration

Both features are **enabled by default**. To disable:

```bash
export JARVIS_AUTO_RECALL=false   # Disable auto-recall
export JARVIS_AUTO_CAPTURE=false  # Disable auto-capture
```

## Scripts

Use the provided bash script in the `scripts/` directory:
- `jarvis-memory.sh` - Main CLI tool

## Common Operations

### Save Text as a Seed
```bash
./scripts/jarvis-memory.sh save "Content to remember" "Title of this memory"
```

### Semantic Search
```bash
./scripts/jarvis-memory.sh search "what do I know about embeddings" 10 0.5
```

### Create Agent Context
```bash
./scripts/jarvis-memory.sh context-create "my-agent" "episodic" '{"key":"value"}'
```

### List Agent Contexts
```bash
./scripts/jarvis-memory.sh context-list "my-agent"
```

### Get Specific Context
```bash
./scripts/jarvis-memory.sh context-get abc-123
```

## Interaction Seeds (Dual Storage)

When JarvisMemoryBot processes an interaction, it stores data in two places:

1. **Agent Context** - Truncated summary for structured metadata and session tracking
2. **Seed** - Full thread snapshot for semantic search

Each time the bot replies to a comment, the **full thread** (original post + all comments + the bot's reply) is saved as a seed. This means:

- Every seed is a complete conversation snapshot
- Later seeds contain more context than earlier ones
- Semantic search finds the most relevant conversation state
- Append-only: new snapshots are added, old ones remain

### Seed Format

```
Thread snapshot - {timestamp}

Post: {full post content}

Comments:
{author1}: {comment text}
{author2}: {comment text}
JarvisMemoryBot: {reply text}
```

## API Endpoints

- `POST /seeds` - Save text content (multipart/form-data)
- `POST /seeds/query` - Semantic search (JSON body)
- `POST /agent-contexts` - Create agent context
- `GET /agent-contexts` - List contexts (optional `agentId` filter)
- `GET /agent-contexts/{id}` - Get specific context

**Base URL:** `http://localhost:8080`
**Auth:** None required.

**Memory types:** `episodic`, `semantic`, `procedural`, `working`

**Text types for seeds:** `text`, `markdown`, `json`, `csv`, `claude_chat`, `gpt_chat`, `email`
