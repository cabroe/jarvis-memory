#!/usr/bin/env bash

# Command-line tool for Jarvis Memory API
# Assumes the API is running at http://localhost:8080

API_URL="http://localhost:8080"

# Colors for output
RED='\03.3[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

function show_help {
  echo -e "Jarvis Memory CLI Tool"
  echo -e "Usage:"
  echo -e "  $0 test                                        - Test the API connection"
  echo -e "  $0 save <content> <title> [type]               - Save a new memory seed"
  echo -e "  $0 search <query> [limit] [threshold]          - Semantic search for memories"
  echo -e "  $0 context-create <agent_id> <type> <metadata> - Create an agent context"
  echo -e "  $0 context-list <agent_id>                     - List contexts for an agent"
  echo -e "  $0 context-get <id>                            - Get a specific context by ID"
}

case "$1" in
  test)
    echo "Testing connection to Jarvis Memory at $API_URL/admin..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/admin")
    if [ "$HTTP_CODE" -eq 200 ]; then
      echo -e "${GREEN}SUCCESS${NC}: Jarvis Memory API is reachable."
    else
      echo -e "${RED}FAILURE${NC}: Could not reach API. HTTP status: $HTTP_CODE"
    fi
    ;;
  
  save)
    CONTENT="$2"
    TITLE="$3"
    TYPE="${4:-markdown}"
    
    if [ -z "$CONTENT" ] || [ -z "$TITLE" ]; then
      echo "Error: Content and title are required."
      show_help
      exit 1
    fi
    
    echo "Saving memory..."
    curl -s -X POST "$API_URL/seeds" \
      -F "content=$CONTENT" \
      -F "title=$TITLE" \
      -F "type=$TYPE" | jq
    ;;
    
  search)
    QUERY="$2"
    LIMIT="${3:-10}"
    THRESHOLD="${4:-0.0}"
    
    if [ -z "$QUERY" ]; then
      echo "Error: Query is required."
      show_help
      exit 1
    fi
    
    echo "Searching..."
    curl -s -X POST "$API_URL/seeds/query" \
      -H "Content-Type: application/json" \
      -d "{\"query\": \"$QUERY\", \"limit\": $LIMIT, \"threshold\": $THRESHOLD}" | jq
    ;;
    
  context-create)
    AGENT_ID="$2"
    TYPE="$3"
    METADATA="$4"
    SUMMARY="$5"
    
    if [ -z "$AGENT_ID" ] || [ -z "$TYPE" ] || [ -z "$METADATA" ]; then
      echo "Error: agent_id, type, and metadata are required."
      show_help
      exit 1
    fi
    
    echo "Creating agent context..."
    curl -s -X POST "$API_URL/agent-contexts" \
      -H "Content-Type: application/json" \
      -d "{\"agentId\": \"$AGENT_ID\", \"type\": \"$TYPE\", \"metadata\": $METADATA, \"summary\": \"$SUMMARY\"}" | jq
    ;;
    
  context-list)
    AGENT_ID="$2"
    
    if [ -z "$AGENT_ID" ]; then
      echo "Listing all contexts..."
      curl -s "$API_URL/agent-contexts" | jq
    else
      echo "Listing contexts for agent $AGENT_ID..."
      curl -s "$API_URL/agent-contexts?agentId=$AGENT_ID" | jq
    fi
    ;;
    
  context-get)
    ID="$2"
    
    if [ -z "$ID" ]; then
      echo "Error: Context ID is required."
      show_help
      exit 1
    fi
    
    echo "Getting context $ID..."
    curl -s "$API_URL/agent-contexts/$ID" | jq
    ;;
    
  *)
    show_help
    ;;
esac
