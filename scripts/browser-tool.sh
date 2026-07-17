#!/bin/bash
# doit-skill browser tool for OMP integration
# Usage: ./scripts/browser-tool.sh [open|click|type|fill|screenshot|extract|close|status] [url/selector] [text]

set -e

DOIT_DIR="$HOME/.doit"
BROWSER_LOG="$DOIT_DIR/browser-log.json"
BROWSER_STATE="$DOIT_DIR/browser-state.json"

# Initialize browser log if not exists
if [ ! -f "$BROWSER_LOG" ]; then
  cat > "$BROWSER_LOG" <<'EOF'
{
  "version": "1.0",
  "actions": [],
  "created": "",
  "updated": ""
}
EOF
fi

# Initialize browser state if not exists
if [ ! -f "$BROWSER_STATE" ]; then
  cat > "$BROWSER_STATE" <<'EOF'
{
  "version": "1.0",
  "current_url": null,
  "current_tab": null,
  "created": "",
  "updated": ""
}
EOF
fi

# Parse arguments
ACTION="${1:-status}"
URL_OR_SELECTOR="${2:-}"
TEXT="${3:-}"

case "$ACTION" in
  status)
    # Show browser status
    if [ -f "$BROWSER_STATE" ]; then
      CURRENT_URL=$(grep '"current_url":' "$BROWSER_STATE" | cut -d' ' -f2 | tr -d '"' | tr -d ',')
      
      if [ -n "$CURRENT_URL" ]; then
        echo "Browser status:"
        echo "  Active: true"
        echo "  URL: $CURRENT_URL"
      else
        echo "Browser status:"
        echo "  Active: false"
      fi
    else
      echo "No browser state found"
    fi
    ;;
  
  open)
    # Open URL
    if [ -z "$URL_OR_SELECTOR" ]; then
      echo "Usage: $0 open <url>"
      exit 1
    fi
    
    echo "Opening: $URL_OR_SELECTOR"
    
    # Try OMP browser first
    if command -v omp &> /dev/null; then
      RESULT=$(omp browser open "$URL_OR_SELECTOR" 2>/dev/null || echo "OMP browser failed")
    else
      # Fallback to xdg-open
      if command -v xdg-open &> /dev/null; then
        xdg-open "$URL_OR_SELECTOR" &>/dev/null &
        RESULT="Opened in default browser"
      elif command -v open &> /dev/null; then
        open "$URL_OR_SELECTOR" &>/dev/null &
        RESULT="Opened in default browser"
      else
        echo "No browser available"
        exit 1
      fi
    fi
    
    # Update browser state
    cat > "$BROWSER_STATE" <<EOF
{
  "version": "1.0",
  "current_url": "$URL_OR_SELECTOR",
  "current_tab": "main",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    # Log action
    EXISTING=$(cat "$BROWSER_LOG")
    cat > "$BROWSER_LOG" <<EOF
{
  "version": "1.0",
  "actions": [
    $(echo "$EXISTING" | grep '"actions"' | grep -v '^\s*\[' | head -1)
    {
      "action": "open",
      "url": "$URL_OR_SELECTOR",
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
  
  click)
    # Click element
    if [ -z "$URL_OR_SELECTOR" ]; then
      echo "Usage: $0 click <selector>"
      exit 1
    fi
    
    echo "Clicking: $URL_OR_SELECTOR"
    
    # Try OMP browser
    if command -v omp &> /dev/null; then
      RESULT=$(omp browser click "$URL_OR_SELECTOR" 2>/dev/null || echo "OMP browser click failed")
    else
      RESULT="Click not available (no browser control)"
    fi
    
    # Log action
    EXISTING=$(cat "$BROWSER_LOG")
    cat > "$BROWSER_LOG" <<EOF
{
  "version": "1.0",
  "actions": [
    $(echo "$EXISTING" | grep '"actions"' | grep -v '^\s*\[' | head -1)
    {
      "action": "click",
      "selector": "$URL_OR_SELECTOR",
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
  
  type)
    # Type text
    if [ -z "$URL_OR_SELECTOR" ] || [ -z "$TEXT" ]; then
      echo "Usage: $0 type <selector> <text>"
      exit 1
    fi
    
    echo "Typing: $TEXT into $URL_OR_SELECTOR"
    
    # Try OMP browser
    if command -v omp &> /dev/null; then
      RESULT=$(omp browser type "$URL_OR_SELECTOR" "$TEXT" 2>/dev/null || echo "OMP browser type failed")
    else
      RESULT="Type not available (no browser control)"
    fi
    
    # Log action
    EXISTING=$(cat "$BROWSER_LOG")
    cat > "$BROWSER_LOG" <<EOF
{
  "version": "1.0",
  "actions": [
    $(echo "$EXISTING" | grep '"actions"' | grep -v '^\s*\[' | head -1)
    {
      "action": "type",
      "selector": "$URL_OR_SELECTOR",
      "text": "$TEXT",
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
  
  fill)
    # Fill form field
    if [ -z "$URL_OR_SELECTOR" ] || [ -z "$TEXT" ]; then
      echo "Usage: $0 fill <selector> <value>"
      exit 1
    fi
    
    echo "Filling: $TEXT into $URL_OR_SELECTOR"
    
    # Try OMP browser
    if command -v omp &> /dev/null; then
      RESULT=$(omp browser fill "$URL_OR_SELECTOR" "$TEXT" 2>/dev/null || echo "OMP browser fill failed")
    else
      RESULT="Fill not available (no browser control)"
    fi
    
    # Log action
    EXISTING=$(cat "$BROWSER_LOG")
    cat > "$BROWSER_LOG" <<EOF
{
  "version": "1.0",
  "actions": [
    $(echo "$EXISTING" | grep '"actions"' | grep -v '^\s*\[' | head -1)
    {
      "action": "fill",
      "selector": "$URL_OR_SELECTOR",
      "value": "$TEXT",
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
  
  screenshot)
    # Take screenshot
    echo "Taking screenshot..."
    
    # Try OMP browser
    if command -v omp &> /dev/null; then
      RESULT=$(omp browser screenshot 2>/dev/null || echo "OMP browser screenshot failed")
    else
      RESULT="Screenshot not available (no browser control)"
    fi
    
    # Log action
    EXISTING=$(cat "$BROWSER_LOG")
    cat > "$BROWSER_LOG" <<EOF
{
  "version": "1.0",
  "actions": [
    $(echo "$EXISTING" | grep '"actions"' | grep -v '^\s*\[' | head -1)
    {
      "action": "screenshot",
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
  
  extract)
    # Extract page content
    echo "Extracting page content..."
    
    # Try OMP browser
    if command -v omp &> /dev/null; then
      RESULT=$(omp browser extract 2>/dev/null || echo "OMP browser extract failed")
    else
      RESULT="Extract not available (no browser control)"
    fi
    
    # Log action
    EXISTING=$(cat "$BROWSER_LOG")
    cat > "$BROWSER_LOG" <<EOF
{
  "version": "1.0",
  "actions": [
    $(echo "$EXISTING" | grep '"actions"' | grep -v '^\s*\[' | head -1)
    {
      "action": "extract",
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
  
  close)
    # Close browser
    echo "Closing browser..."
    
    # Try OMP browser
    if command -v omp &> /dev/null; then
      RESULT=$(omp browser close 2>/dev/null || echo "OMP browser close failed")
    else
      RESULT="Close not available (no browser control)"
    fi
    
    # Reset browser state
    cat > "$BROWSER_STATE" <<EOF
{
  "version": "1.0",
  "current_url": null,
  "current_tab": null,
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    # Log action
    EXISTING=$(cat "$BROWSER_LOG")
    cat > "$BROWSER_LOG" <<EOF
{
  "version": "1.0",
  "actions": [
    $(echo "$EXISTING" | grep '"actions"' | grep -v '^\s*\[' | head -1)
    {
      "action": "close",
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
  
  *)
    echo "Usage: $0 [open|click|type|fill|screenshot|extract|close|status] [url/selector] [text]"
    exit 1
    ;;
esac