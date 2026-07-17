#!/bin/bash
# doit-skill DAP debugging tool for OMP integration
# Usage: ./scripts/dap-tool.sh [start|stop|breakpoint|continue|next|step|step_out|evaluate|variables|stack_trace|threads|status] [params]

set -e

DOIT_DIR="$HOME/.doit"
DAP_LOG="$DOIT_DIR/dap-log.json"
DAP_STATE="$DOIT_DIR/dap-state.json"

# Initialize DAP log if not exists
if [ ! -f "$DAP_LOG" ]; then
  cat > "$DAP_LOG" <<'EOF'
{
  "version": "1.0",
  "actions": [],
  "created": "",
  "updated": ""
}
EOF
fi

# Initialize DAP state if not exists
if [ ! -f "$DAP_STATE" ]; then
  cat > "$DAP_STATE" <<'EOF'
{
  "version": "1.0",
  "running": false,
  "pid": null,
  "current_frame": null,
  "breakpoints": [],
  "created": "",
  "updated": ""
}
EOF
fi

# Parse arguments
ACTION="${1:-status}"
PARAM1="${2:-}"
PARAM2="${3:-}"

case "$ACTION" in
  status)
    # Show DAP status
    if grep -q '"running": true' "$DAP_STATE"; then
      RUNNING="true"
      PID=$(grep '"pid":' "$DAP_STATE" | cut -d' ' -f2 | tr -d '"' | tr -d ',')
      echo "DAP status:"
      echo "  Running: $RUNNING"
      echo "  PID: $PID"
    else
      echo "DAP status:"
      echo "  Running: false"
    fi
    ;;
  
  start)
    # Start debugger
    if [ -z "$PARAM1" ]; then
      echo "Usage: $0 start <program> [args...]"
      exit 1
    fi
    
    echo "Starting debugger for: $PARAM1"
    
    # Try OMP dap.startDebugger first
    if command -v omp &> /dev/null; then
      RESULT=$(omp dap startDebugger "{ program: \"$PARAM1\" }" 2>/dev/null || echo "OMP DAP failed")
    else
      RESULT="DAP not available (no OMP or debugger configured)"
    fi
    
    # Update DAP state
    cat > "$DAP_STATE" <<EOF
{
  "version": "1.0",
  "running": true,
  "pid": "debugger",
  "current_frame": null,
  "breakpoints": [],
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    # Log action
    EXISTING=$(cat "$DAP_LOG")
    cat > "$DAP_LOG" <<EOF
{
  "version": "1.0",
  "actions": [
    $(echo "$EXISTING" | grep '"actions"' | grep -v '^\s*\[' | head -1)
    {
      "action": "start",
      "program": "$PARAM1",
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
  
  stop)
    # Stop debugger
    echo "Stopping debugger..."
    
    # Try OMP dap.terminate
    if command -v omp &> /dev/null; then
      RESULT=$(omp dap terminate 2>/dev/null || echo "OMP DAP terminate failed")
    else
      RESULT="DAP stop not available"
    fi
    
    # Update DAP state
    cat > "$DAP_STATE" <<EOF
{
  "version": "1.0",
  "running": false,
  "pid": null,
  "current_frame": null,
  "breakpoints": [],
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    # Log action
    EXISTING=$(cat "$DAP_LOG")
    cat > "$DAP_LOG" <<EOF
{
  "version": "1.0",
  "actions": [
    $(echo "$EXISTING" | grep '"actions"' | grep -v '^\s*\[' | head -1)
    {
      "action": "stop",
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
  
  breakpoint)
    # Set breakpoint
    if [ -z "$PARAM1" ] || [ -z "$PARAM2" ]; then
      echo "Usage: $0 breakpoint <file> <line>"
      exit 1
    fi
    
    echo "Setting breakpoint: $PARAM1:$PARAM2"
    
    # Try OMP dap.setBreakpoint
    if command -v omp &> /dev/null; then
      RESULT=$(omp dap setBreakpoint "$PARAM1" "$PARAM2" 2>/dev/null || echo "OMP DAP breakpoint failed")
    else
      RESULT="DAP breakpoint not available"
    fi
    
    # Update DAP state
    BP_FILE=$(grep '"breakpoints"' "$DAP_STATE" | sed 's/.*\[\(.*\)\].*/\1/' || echo "")
    NEW_BP="$BP_FILE,{\"file\": \"$PARAM1\", \"line\": $PARAM2}"
    cat > "$DAP_STATE" <<EOF
{
  "version": "1.0",
  "running": $(grep '"running":' "$DAP_STATE" | cut -d' ' -f2 | tr -d ', ' || echo "true"),
  "pid": $(grep '"pid":' "$DAP_STATE" | cut -d' ' -f2 | tr -d '"' | tr -d ',' || echo "null"),
  "current_frame": $(grep '"current_frame":' "$DAP_STATE" | cut -d' ' -f2 | tr -d '"' | tr -d ',' || echo "null"),
  "breakpoints": [$NEW_BP],
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    # Log action
    EXISTING=$(cat "$DAP_LOG")
    cat > "$DAP_LOG" <<EOF
{
  "version": "1.0",
  "actions": [
    $(echo "$EXISTING" | grep '"actions"' | grep -v '^\s*\[' | head -1)
    {
      "action": "breakpoint",
      "file": "$PARAM1",
      "line": "$PARAM2",
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
  
  continue)
    echo "Continuing execution..."
    
    if command -v omp &> /dev/null; then
      RESULT=$(omp dap continue 2>/dev/null || echo "OMP DAP continue failed")
    else
      RESULT="DAP continue not available"
    fi
    
    EXISTING=$(cat "$DAP_LOG")
    cat > "$DAP_LOG" <<EOF
{
  "version": "1.0",
  "actions": [
    $(echo "$EXISTING" | grep '"actions"' | grep -v '^\s*\[' | head -1)
    {
      "action": "continue",
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
  
  next)
    echo "Stepping over..."
    
    if command -v omp &> /dev/null; then
      RESULT=$(omp dap next 2>/dev/null || echo "OMP DAP next failed")
    else
      RESULT="DAP next not available"
    fi
    
    EXISTING=$(cat "$DAP_LOG")
    cat > "$DAP_LOG" <<EOF
{
  "version": "1.0",
  "actions": [
    $(echo "$EXISTING" | grep '"actions"' | grep -v '^\s*\[' | head -1)
    {
      "action": "next",
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
  
  step)
    echo "Stepping into..."
    
    if command -v omp &> /dev/null; then
      RESULT=$(omp dap stepIn 2>/dev/null || echo "OMP DAP stepIn failed")
    else
      RESULT="DAP step into not available"
    fi
    
    EXISTING=$(cat "$DAP_LOG")
    cat > "$DAP_LOG" <<EOF
{
  "version": "1.0",
  "actions": [
    $(echo "$EXISTING" | grep '"actions"' | grep -v '^\s*\[' | head -1)
    {
      "action": "step_into",
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
  
  step_out)
    echo "Stepping out..."
    
    if command -v omp &> /dev/null; then
      RESULT=$(omp dap stepOut 2>/dev/null || echo "OMP DAP stepOut failed")
    else
      RESULT="DAP step out not available"
    fi
    
    EXISTING=$(cat "$DAP_LOG")
    cat > "$DAP_LOG" <<EOF
{
  "version": "1.0",
  "actions": [
    $(echo "$EXISTING" | grep '"actions"' | grep -v '^\s*\[' | head -1)
    {
      "action": "step_out",
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
  
  evaluate)
    if [ -z "$PARAM1" ]; then
      echo "Usage: $0 evaluate <expression>"
      exit 1
    fi
    
    echo "Evaluating: $PARAM1"
    
    if command -v omp &> /dev/null; then
      RESULT=$(omp dap evaluate "$PARAM1" 2>/dev/null || echo "OMP DAP evaluate failed")
    else
      RESULT="DAP evaluate not available"
    fi
    
    EXISTING=$(cat "$DAP_LOG")
    cat > "$DAP_LOG" <<EOF
{
  "version": "1.0",
  "actions": [
    $(echo "$EXISTING" | grep '"actions"' | grep -v '^\s*\[' | head -1)
    {
      "action": "evaluate",
      "expression": "$PARAM1",
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
  
  variables)
    if [ -z "$PARAM1" ]; then
      echo "Usage: $0 variables <frame_id>"
      exit 1
    fi
    
    echo "Getting variables for frame: $PARAM1"
    
    if command -v omp &> /dev/null; then
      RESULT=$(omp dap variables "$PARAM1" 2>/dev/null || echo "OMP DAP variables failed")
    else
      RESULT="DAP variables not available"
    fi
    
    EXISTING=$(cat "$DAP_LOG")
    cat > "$DAP_LOG" <<EOF
{
  "version": "1.0",
  "actions": [
    $(echo "$EXISTING" | grep '"actions"' | grep -v '^\s*\[' | head -1)
    {
      "action": "variables",
      "frame_id": "$PARAM1",
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
  
  stack_trace)
    echo "Getting stack trace..."
    
    if command -v omp &> /dev/null; then
      RESULT=$(omp dap stackTrace 2>/dev/null || echo "OMP DAP stackTrace failed")
    else
      RESULT="DAP stack trace not available"
    fi
    
    EXISTING=$(cat "$DAP_LOG")
    cat > "$DAP_LOG" <<EOF
{
  "version": "1.0",
  "actions": [
    $(echo "$EXISTING" | grep '"actions"' | grep -v '^\s*\[' | head -1)
    {
      "action": "stack_trace",
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
  
  threads)
    echo "Getting threads..."
    
    if command -v omp &> /dev/null; then
      RESULT=$(omp dap threads 2>/dev/null || echo "OMP DAP threads failed")
    else
      RESULT="DAP threads not available"
    fi
    
    EXISTING=$(cat "$DAP_LOG")
    cat > "$DAP_LOG" <<EOF
{
  "version": "1.0",
  "actions": [
    $(echo "$EXISTING" | grep '"actions"' | grep -v '^\s*\[' | head -1)
    {
      "action": "threads",
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
    echo "Usage: $0 [start|stop|breakpoint|continue|next|step|step_out|evaluate|variables|stack_trace|threads|status] [params]"
    exit 1
    ;;
esac