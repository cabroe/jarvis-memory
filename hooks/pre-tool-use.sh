#!/usr/bin/env bash
# Auto-Recall: Query memories before AI turn and inject as context
# This hook runs before each tool use

# Check if auto-recall is enabled (default: true)
JARVIS_AUTO_RECALL="${JARVIS_AUTO_RECALL:-true}"
[[ "$JARVIS_AUTO_RECALL" != "true" ]] && exit 0

set -euo pipefail

API_BASE="http://localhost:8080"

# Get the user's latest message from stdin (OpenClaw passes context)
USER_MESSAGE="${OPENCLAW_USER_MESSAGE:-}"

if [[ -z "$USER_MESSAGE" ]]; then
    exit 0
fi

# Query for relevant memories from local Jarvis Memory API
# Threshold is set to 0.5 to only return somewhat relevant memories
response=$(curl -s -X POST "${API_BASE}/seeds/query" \
    -H "Content-Type: application/json" \
    -d "{\"query\":\"${USER_MESSAGE}\",\"limit\":5,\"threshold\":0.5}" 2>/dev/null || echo "[]")

# Extract memory content if any
# The API returns a JSON array of hit objects. We want the `content` of each.
memories=$(echo "$response" | jq -r '.[].content? // empty' 2>/dev/null | head -n 5)

if [[ -n "$memories" ]]; then
    echo "---"
    echo "RECALLED MEMORIES FROM JARVIS:"
    echo "$memories"
    echo "---"
fi
