#!/bin/bash
# doit-skill web search tool for OMP integration
# Usage: ./scripts/web-search-tool.sh [search|fetch|browser] [query/url]

set -e

DOIT_DIR="$HOME/.doit"
SEARCH_LOG="$DOIT_DIR/search-log.json"

# Initialize search log if not exists
if [ ! -f "$SEARCH_LOG" ]; then
  cat > "$SEARCH_LOG" <<'EOF'
{
  "version": "1.0",
  "searches": [],
  "created": "",
  "updated": ""
}
EOF
fi

# Parse arguments
ACTION="${1:-search}"
QUERY="${2:-}"

case "$ACTION" in
  search)
    # Search the web
    if [ -z "$QUERY" ]; then
      echo "Usage: $0 search <query>"
      exit 1
    fi
    
    echo "Searching: $QUERY"
    
    # Try MCP web_search first
    if command -v web_search &> /dev/null; then
      RESULT=$(web_search "$QUERY" 2>/dev/null || echo "MCP not available")
    else
      # Fallback to curl-based search
      RESULT=$(curl -s "https://search.brave.com/search?q=$(echo "$QUERY" | sed 's/ /+/g')" 2>/dev/null | grep -oP '<span class="snippet-description">.*?</span>' | head -1 | sed 's/<[^>]*>//g' || echo "Search unavailable")
    fi
    
    # Log search
    EXISTING=$(cat "$SEARCH_LOG")
    cat > "$SEARCH_LOG" <<EOF
{
  "version": "1.0",
  "searches": [
    $(echo "$EXISTING" | grep '"searches"' | grep -v '^\s*\[' | head -1)
    {
      "query": "$QUERY",
      "result": "$RESULT",
      "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    }
  ],
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    echo "$RESULT"
    ;;
  
  fetch)
    # Fetch a URL
    if [ -z "$QUERY" ]; then
      echo "Usage: $0 fetch <url>"
      exit 1
    fi
    
    echo "Fetching: $QUERY"
    
    # Try MCP web_fetch first
    if command -v web_fetch &> /dev/null; then
      RESULT=$(web_fetch "$QUERY" 2>/dev/null || echo "MCP not available")
    else
      # Fallback to curl
      RESULT=$(curl -s "$QUERY" 2>/dev/null | head -c 1000 || echo "Fetch failed")
    fi
    
    # Log fetch
    EXISTING=$(cat "$SEARCH_LOG")
    cat > "$SEARCH_LOG" <<EOF
{
  "version": "1.0",
  "searches": [
    $(echo "$EXISTING" | grep '"searches"' | grep -v '^\s*\[' | head -1)
    {
      "url": "$QUERY",
      "type": "fetch",
      "result": "$RESULT",
      "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    }
  ],
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    echo "$RESULT"
    ;;
  
  browser)
    # Open URL in browser
    if [ -z "$QUERY" ]; then
      echo "Usage: $0 browser <url>"
      exit 1
    fi
    
    echo "Opening in browser: $QUERY"
    
    # Try OMP browser first
    if command -v omp &> /dev/null; then
      RESULT=$(omp browser open "$QUERY" 2>/dev/null || echo "OMP browser not available")
    else
      # Fallback to xdg-open
      if command -v xdg-open &> /dev/null; then
        xdg-open "$QUERY" &>/dev/null &
        echo "Opened in default browser"
      elif command -v open &> /dev/null; then
        open "$QUERY" &>/dev/null &
        echo "Opened in default browser"
      else
        echo "No browser available"
        exit 1
      fi
    fi
    
    # Log browser usage
    EXISTING=$(cat "$SEARCH_LOG")
    cat > "$SEARCH_LOG" <<EOF
{
  "version": "1.0",
  "searches": [
    $(echo "$EXISTING" | grep '"searches"' | grep -v '^\s*\[' | head -1)
    {
      "url": "$QUERY",
      "type": "browser",
      "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    }
  ],
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    ;;
  
  *)
    echo "Usage: $0 [search|fetch|browser] <query/url>"
    exit 1
    ;;
esac