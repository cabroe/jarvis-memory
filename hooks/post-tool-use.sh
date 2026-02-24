#!/usr/bin/env bash
# Auto-Capture: Save conversation after AI turn (Dual Storage)
# This hook runs after each AI turn to persist the conversation.
#
# Dual Storage:
#   1. Seed — Full thread snapshot for semantic search
#   2. Agent Context — Truncated summary for structured metadata

# Check if auto-capture is enabled (default: true)
JARVIS_AUTO_CAPTURE="${JARVIS_AUTO_CAPTURE:-true}"
[[ "$JARVIS_AUTO_CAPTURE" != "true" ]] && exit 0

API_BASE="http://localhost:8080"
AGENT_ID="${JARVIS_AGENT_ID:-JARVIS}"

USER_MSG="${OPENCLAW_USER_MESSAGE:-}"
AI_RESP="${OPENCLAW_AI_RESPONSE:-}"

[[ -z "$USER_MSG" && -z "$AI_RESP" ]] && exit 0

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# --- 1. Seed: Thread Snapshot Format ---
TITLE="Thread snapshot - ${TS}"
CONTENT="Thread snapshot - ${TS}

Post: ${USER_MSG}

Comments:
User: ${USER_MSG}
${AGENT_ID}: ${AI_RESP}"

curl -s -X POST "${API_BASE}/seeds" \
    -F "content=${CONTENT}" \
    -F "title=${TITLE}" \
    -F "type=auto_capture" > /dev/null 2>&1 &

# --- 2. Agent Context: Structured Summary ---
# Truncate summary to first 200 chars of AI response
SUMMARY="${AI_RESP:0:200}"

curl -s -X POST "${API_BASE}/agent-contexts" \
    -H "Content-Type: application/json" \
    -d "{
        \"agentId\": \"${AGENT_ID}\",
        \"type\": \"episodic\",
        \"metadata\": {\"timestamp\": \"${TS}\", \"source\": \"auto_capture\"},
        \"summary\": $(echo "$SUMMARY" | jq -Rs .)
    }" > /dev/null 2>&1 &
