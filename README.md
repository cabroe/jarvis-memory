# Jarvis Memory

A local, lightweight, purely Go-based recreation of the "Vanar Neutron Memory" skill. It uses a local Postgres instance with `pgvector` for HNSW vector search, and locally generates sentence embeddings via `github.com/rcarmo/gte-go` (GTE-Small).

**Features:**
- 100% API compatibility with the original system.
- Completely local and private (no API keys, no blockchain).
- Embedded Admin Dashboard for easy viewing of data.

---

## Prerequisites

1. **Docker** and **Docker Compose**
2. **Go 1.25+** (for building locally, optional if just using Docker)
3. **Python 3.8+** (for preparing the model once)

---

## 1. Quick Start

The simplest way to start the application and prepare the local embedding models is via the included `Makefile`. It will automatically download the necessary HuggingFace `gte-small` models, convert them, and stand up the database and API via Docker Compose.

```bash
# Setup the models and start the container
make all

# Note: alternatively you can run step by step:
# make setup   (downloads and converts the model)
# make run     (starts docker compose)

# Install the skill to OpenClaw
make skill
```

---

## 3. API Endpoints Reference

The service runs on `http://localhost:8080`.

### Create a Seed
```bash
curl -X POST http://localhost:8080/seeds \
  -F "content=The quick brown fox jumps over the lazy dog." \
  -F "title=Fox jumping" \
  -F "type=markdown"
```

### Query Seeds
```bash
curl -X POST http://localhost:8080/seeds/query \
  -H "Content-Type: application/json" \
  -d '{"query": "animal jumping", "limit": 5, "threshold": 0.5}'
```

### Create Agent Context
```bash
curl -X POST http://localhost:8080/agent-contexts \
  -H "Content-Type: application/json" \
  -d '{"agentId": "agent-123", "type": "episodic", "summary": "Found a new path", "metadata": {"location": "forest", "status": "active"}}'
```

### Get Agent Contexts (All or by AgentID)
```bash
# All
curl http://localhost:8080/agent-contexts

# Filtered
curl "http://localhost:8080/agent-contexts?agentId=agent-123"
```

### Get Agent Context by ID
```bash
curl http://localhost:8080/agent-contexts/UUID-GOES-HERE
```

---

## 4. Admin Panel

Open your browser to:
`http://localhost:8080/admin`

The dashboard will give you a quick, paginated and sortable overview of all the Seeds and Agent Contexts stored in the database.
