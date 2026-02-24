#!/usr/bin/env bash

# Command-line tool for Jarvis Memory API
# Assumes the API is running at http://localhost:8080

API_URL="${JARVIS_API_URL:-http://localhost:8080}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

function show_help {
  echo -e "${CYAN}🧠 Jarvis Memory CLI${NC}"
  echo -e ""
  echo -e "Usage: $0 <command> [args]"
  echo -e ""
  echo -e "${GREEN}Seeds (Memory):${NC}"
  echo -e "  save <content> <title> [type]         💾 Save a new memory seed"
  echo -e "  search <query> [limit] [threshold] [--since X] [--until X]"
  echo -e "                                        🔍 Semantic search (time: today|yesterday|this_week|last_week|YYYY-MM-DD)"
  echo -e "  update <id> <content> <title> [type]  ✏️  Update an existing seed"
  echo -e "  delete <id>                           🗑️  Delete a seed"
  echo -e "  confidence <id> <value>               ⚖️  Set confidence (0.0-1.0)"
  echo -e ""
  echo -e "${GREEN}Agent Contexts:${NC}"
  echo -e "  context-create <agent_id> <type> <metadata> [summary]"
  echo -e "  context-list [agent_id]               📋 List contexts"
  echo -e "  context-get <id>                      🔎 Get specific context"
  echo -e ""
  echo -e "${GREEN}Admin:${NC}"
  echo -e "  stats                                 📊 Show database statistics"
  echo -e "  list [limit]                          📋 List latest seeds"
  echo -e "  reflect [day]                         🪞 Daily self-reflection (default: today)"
  echo -e "  export [file]                         📦 Export all data as JSON"
  echo -e "  import <file>                         📥 Import data from JSON backup"
  echo -e "  test                                  🧪 Test API connection"
}

case "$1" in
  test)
    echo "Testing connection to Jarvis Memory at $API_URL..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/admin")
    if [ "$HTTP_CODE" -eq 200 ]; then
      echo -e "${GREEN}✅ SUCCESS${NC}: Jarvis Memory API is reachable."
    else
      echo -e "${RED}❌ FAILURE${NC}: Could not reach API. HTTP status: $HTTP_CODE"
    fi
    ;;
  
  save)
    CONTENT="$2"
    TITLE="$3"
    TYPE="${4:-markdown}"
    
    if [ -z "$CONTENT" ] || [ -z "$TITLE" ]; then
      echo -e "${RED}Error: content and title are required.${NC}"
      echo "Usage: $0 save <content> <title> [type]"
      exit 1
    fi
    
    echo -e "💾 Saving memory..."
    curl -s -X POST "$API_URL/seeds" \
      -F "content=$CONTENT" \
      -F "title=$TITLE" \
      -F "type=$TYPE" | jq
    ;;

  update)
    ID="$2"
    CONTENT="$3"
    TITLE="$4"
    TYPE="${5:-markdown}"

    if [ -z "$ID" ] || [ -z "$CONTENT" ] || [ -z "$TITLE" ]; then
      echo -e "${RED}Error: id, content, and title are required.${NC}"
      echo "Usage: $0 update <id> <content> <title> [type]"
      exit 1
    fi

    echo -e "✏️  Updating seed $ID..."
    curl -s -X PUT "$API_URL/seeds/$ID" \
      -H "Content-Type: application/json" \
      -d "{\"content\": $(echo "$CONTENT" | jq -Rs .), \"title\": $(echo "$TITLE" | jq -Rs .), \"type\": \"$TYPE\"}" | jq
    ;;

  delete)
    ID="$2"

    if [ -z "$ID" ]; then
      echo -e "${RED}Error: seed ID is required.${NC}"
      echo "Usage: $0 delete <id>"
      exit 1
    fi

    echo -e "${YELLOW}🗑️  Deleting seed $ID...${NC}"
    curl -s -X DELETE "$API_URL/seeds/$ID" | jq
    ;;

  confidence)
    ID="$2"
    VALUE="$3"

    if [ -z "$ID" ] || [ -z "$VALUE" ]; then
      echo -e "${RED}Error: id and confidence value are required.${NC}"
      echo "Usage: $0 confidence <id> <value (0.0-1.0)>"
      exit 1
    fi

    echo -e "⚖️  Setting confidence for $ID to $VALUE..."
    curl -s -X POST "$API_URL/seeds/$ID/confidence" \
      -H "Content-Type: application/json" \
      -d "{\"confidence\": $VALUE}" | jq
    ;;
    
  search)
    QUERY=""
    LIMIT="10"
    THRESHOLD="0.0"
    SINCE=""
    UNTIL=""

    shift # remove "search"
    while [ $# -gt 0 ]; do
      case "$1" in
        --since) SINCE="$2"; shift 2 ;;
        --until) UNTIL="$2"; shift 2 ;;
        *)
          if [ -z "$QUERY" ]; then QUERY="$1"
          elif [ "$LIMIT" = "10" ] && [[ "$1" =~ ^[0-9]+$ ]]; then LIMIT="$1"
          else THRESHOLD="$1"
          fi
          shift ;;
      esac
    done

    if [ -z "$QUERY" ]; then
      echo -e "${RED}Error: query is required.${NC}"
      echo "Usage: $0 search <query> [limit] [threshold] [--since today|yesterday|this_week|last_week|YYYY-MM-DD] [--until ...]"
      exit 1
    fi

    # Build JSON payload
    JSON="{\"query\": $(echo "$QUERY" | jq -Rs .), \"limit\": $LIMIT, \"threshold\": $THRESHOLD"
    [ -n "$SINCE" ] && JSON="$JSON, \"since\": \"$SINCE\""
    [ -n "$UNTIL" ] && JSON="$JSON, \"until\": \"$UNTIL\""
    JSON="$JSON}"

    echo -e "🔍 Searching..."
    [ -n "$SINCE" ] && echo -e "  📅 Since: ${CYAN}$SINCE${NC}"
    [ -n "$UNTIL" ] && echo -e "  📅 Until: ${CYAN}$UNTIL${NC}"
    curl -s -X POST "$API_URL/seeds/query" \
      -H "Content-Type: application/json" \
      -d "$JSON" | jq
    ;;

  list)
    LIMIT="${2:-20}"
    echo -e "📋 Latest $LIMIT seeds..."
    curl -s "$API_URL/seeds?limit=$LIMIT" | jq '.[] | {id, title, type, confidence, created_at}'
    ;;

  stats)
    echo -e "${CYAN}📊 Jarvis Memory Statistics${NC}"
    SEEDS=$(curl -s "$API_URL/seeds?limit=1000")
    CTXS=$(curl -s "$API_URL/agent-contexts")
    SEED_COUNT=$(echo "$SEEDS" | jq 'length')
    CTX_COUNT=$(echo "$CTXS" | jq 'length')
    echo -e "  🌱 Seeds:          ${GREEN}$SEED_COUNT${NC}"
    echo -e "  🤖 Agent Contexts: ${GREEN}$CTX_COUNT${NC}"
    echo -e ""
    echo -e "${CYAN}Seeds by Type:${NC}"
    echo "$SEEDS" | jq -r 'group_by(.type) | .[] | "  \(.[0].type): \(length)"'
    echo -e ""
    echo -e "${CYAN}Avg Confidence:${NC}"
    echo "$SEEDS" | jq -r '(map(.confidence) | add / length) | "  \(. * 100 | round)%"'
    ;;

  context-create)
    AGENT_ID="$2"
    TYPE="$3"
    METADATA="$4"
    SUMMARY="$5"
    
    if [ -z "$AGENT_ID" ] || [ -z "$TYPE" ] || [ -z "$METADATA" ]; then
      echo -e "${RED}Error: agent_id, type, and metadata are required.${NC}"
      echo "Usage: $0 context-create <agent_id> <type> <metadata_json> [summary]"
      exit 1
    fi
    
    echo -e "📝 Creating agent context..."
    curl -s -X POST "$API_URL/agent-contexts" \
      -H "Content-Type: application/json" \
      -d "{\"agentId\": \"$AGENT_ID\", \"type\": \"$TYPE\", \"metadata\": $METADATA, \"summary\": $(echo "$SUMMARY" | jq -Rs .)}" | jq
    ;;
    
  context-list)
    AGENT_ID="$2"
    
    if [ -z "$AGENT_ID" ]; then
      echo -e "📋 Listing all contexts..."
      curl -s "$API_URL/agent-contexts" | jq
    else
      echo -e "📋 Listing contexts for agent $AGENT_ID..."
      curl -s "$API_URL/agent-contexts?agentId=$AGENT_ID" | jq
    fi
    ;;
    
  context-get)
    ID="$2"
    
    if [ -z "$ID" ]; then
      echo -e "${RED}Error: context ID is required.${NC}"
      echo "Usage: $0 context-get <id>"
      exit 1
    fi
    
    echo -e "🔎 Getting context $ID..."
    curl -s "$API_URL/agent-contexts/$ID" | jq
    ;;

  reflect)
    DAY="${2:-today}"
    AGENT_ID="${JARVIS_AGENT_ID:-JARVIS}"
    TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    DATE_HUMAN=$(date -u +"%Y-%m-%d")

    echo -e "${CYAN}🪞 Selbstreflexion für: ${YELLOW}$DAY${NC}"
    echo ""

    # 1. Get all seeds from the target day
    SEEDS=$(curl -s -X POST "$API_URL/seeds/query" \
      -H "Content-Type: application/json" \
      -d "{\"query\": \"Was habe ich gelernt?\", \"limit\": 50, \"threshold\": 0.0, \"since\": \"$DAY\"}")

    COUNT=$(echo "$SEEDS" | jq 'length')

    if [ "$COUNT" -eq 0 ] || [ "$COUNT" = "null" ]; then
      echo -e "${YELLOW}Keine Seeds für '$DAY' gefunden. Nichts zu reflektieren.${NC}"
      exit 0
    fi

    # 2. Extract titles and types
    TITLES=$(echo "$SEEDS" | jq -r '.[].title' | sort -u)
    TYPES=$(echo "$SEEDS" | jq -r '.[].type' | sort | uniq -c | sort -rn)
    CONTENTS=$(echo "$SEEDS" | jq -r '.[].content' | head -c 2000)

    # 3. Build reflection
    REFLECTION="🪞 Tagesreflexion – ${DATE_HUMAN}

📊 Statistik:
- Seeds verarbeitet: ${COUNT}
- Typen: 
$(echo "$TYPES" | while read cnt typ; do echo "  • ${typ}: ${cnt}"; done)

📝 Themen des Tages:
$(echo "$TITLES" | while read t; do echo "  • ${t}"; done)

💡 Zusammenfassung:
$(echo "$CONTENTS" | fold -s -w 120 | head -20)

⏰ Reflexion erstellt: ${TS}"

    echo -e "$REFLECTION"
    echo ""

    # 4. Save as episodic seed
    echo -e "💾 Speichere Reflexion als Seed..."
    curl -s -X POST "$API_URL/seeds" \
      -F "content=${REFLECTION}" \
      -F "title=🪞 Tagesreflexion – ${DATE_HUMAN}" \
      -F "type=episodic" | jq

    # 5. Save agent context
    SUMMARY="Reflexion: ${COUNT} Seeds verarbeitet am ${DATE_HUMAN}"
    curl -s -X POST "$API_URL/agent-contexts" \
      -H "Content-Type: application/json" \
      -d "{\"agentId\": \"${AGENT_ID}\", \"type\": \"episodic\", \"metadata\": {\"action\": \"reflection\", \"date\": \"${DATE_HUMAN}\", \"seed_count\": ${COUNT}}, \"summary\": $(echo "$SUMMARY" | jq -Rs .)}" > /dev/null 2>&1

    echo -e "${GREEN}✅ Reflexion gespeichert!${NC}"
    ;;

  export)
    DATE_STAMP=$(date -u +"%Y%m%d_%H%M%S")
    FILE="${2:-jarvis-memory-backup-${DATE_STAMP}.json}"

    echo -e "📦 Exporting all data..."

    SEEDS=$(curl -s "$API_URL/seeds?limit=10000")
    CONTEXTS=$(curl -s "$API_URL/agent-contexts")

    SEED_COUNT=$(echo "$SEEDS" | jq 'length')
    CTX_COUNT=$(echo "$CONTEXTS" | jq 'length')

    jq -n \
      --argjson seeds "$SEEDS" \
      --argjson contexts "$CONTEXTS" \
      --arg exported_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
      --arg version "1.0" \
      '{
        version: $version,
        exported_at: $exported_at,
        seeds: $seeds,
        agent_contexts: $contexts
      }' > "$FILE"

    SIZE=$(du -h "$FILE" | cut -f1)
    echo -e "${GREEN}✅ Export complete!${NC}"
    echo -e "  📄 File:     ${CYAN}$FILE${NC}"
    echo -e "  🌱 Seeds:    $SEED_COUNT"
    echo -e "  🤖 Contexts: $CTX_COUNT"
    echo -e "  💾 Size:     $SIZE"
    ;;

  import)
    FILE="$2"

    if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
      echo -e "${RED}Error: backup file is required and must exist.${NC}"
      echo "Usage: $0 import <backup.json>"
      exit 1
    fi

    VERSION=$(jq -r '.version // "unknown"' "$FILE")
    EXPORTED=$(jq -r '.exported_at // "unknown"' "$FILE")
    SEED_COUNT=$(jq '.seeds | length' "$FILE")
    CTX_COUNT=$(jq '.agent_contexts | length' "$FILE")

    echo -e "${CYAN}📥 Importing from: ${YELLOW}$FILE${NC}"
    echo -e "  Version:  $VERSION"
    echo -e "  Exported: $EXPORTED"
    echo -e "  🌱 Seeds: $SEED_COUNT"
    echo -e "  🤖 Contexts: $CTX_COUNT"
    echo ""

    read -p "Proceed? (y/N) " CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
      echo "Aborted."
      exit 0
    fi

    # Import seeds
    IMPORTED=0
    FAILED=0
    echo -e "🌱 Importing seeds..."
    for i in $(seq 0 $(($SEED_COUNT - 1))); do
      CONTENT=$(jq -r ".seeds[$i].content" "$FILE")
      TITLE=$(jq -r ".seeds[$i].title" "$FILE")
      TYPE=$(jq -r ".seeds[$i].type" "$FILE")

      RESULT=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API_URL/seeds" \
        -F "content=$CONTENT" \
        -F "title=$TITLE" \
        -F "type=$TYPE")

      if [ "$RESULT" -eq 201 ]; then
        IMPORTED=$((IMPORTED + 1))
      else
        FAILED=$((FAILED + 1))
      fi
      printf "\r  Progress: %d/%d (failed: %d)" $((IMPORTED + FAILED)) "$SEED_COUNT" "$FAILED"
    done
    echo ""

    # Import contexts
    CTX_IMPORTED=0
    CTX_FAILED=0
    echo -e "🤖 Importing contexts..."
    for i in $(seq 0 $(($CTX_COUNT - 1))); do
      BODY=$(jq ".agent_contexts[$i] | {agentId: .agentId, type: .type, metadata: .metadata, summary: .summary}" "$FILE")

      RESULT=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API_URL/agent-contexts" \
        -H "Content-Type: application/json" \
        -d "$BODY")

      if [ "$RESULT" -eq 201 ]; then
        CTX_IMPORTED=$((CTX_IMPORTED + 1))
      else
        CTX_FAILED=$((CTX_FAILED + 1))
      fi
      printf "\r  Progress: %d/%d (failed: %d)" $((CTX_IMPORTED + CTX_FAILED)) "$CTX_COUNT" "$CTX_FAILED"
    done
    echo ""

    echo -e ""
    echo -e "${GREEN}✅ Import complete!${NC}"
    echo -e "  🌱 Seeds:    ${IMPORTED} imported, ${FAILED} failed"
    echo -e "  🤖 Contexts: ${CTX_IMPORTED} imported, ${CTX_FAILED} failed"
    ;;
    
  *)
    show_help
    ;;
esac
