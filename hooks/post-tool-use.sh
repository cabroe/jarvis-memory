#!/usr/bin/env bash
# Auto-Capture: Save conversation after AI turn
# This hook runs after each AI turn to persist the conversation

# Check if auto-capture is enabled (default: true)
JARVIS_AUTO_CAPTURE="${JARVIS_AUTO_CAPTURE:-true}"
[[ "$JARVIS_AUTO_CAPTURE" != "true" ]] && exit 0

API_BASE="http://localhost:8080"

USER_MSG="${OPENCLAW_USER_MESSAGE:-}"
AI_RESP="${OPENCLAW_AI_RESPONSE:-}"

[[ -z "$USER_MSG" && -z "$AI_RESP" ]] && exit 0

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TITLE="Conversation - ${TS}"
CONTENT="User: ${USER_MSG}
Assistant: ${AI_RESP}"

# Jarvis Memory does not require authentication or query params API IDs.
# Simply sending the form data to /seeds

curl -s -X POST "${API_BASE}/seeds" \
    -F "content=${CONTENT}" \
    -F "title=${TITLE}" \
    -F "type=auto_capture" > /dev/null 2>&1 &
