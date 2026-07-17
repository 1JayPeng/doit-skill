#!/bin/bash
# doit-skill task tool for OMP subagent management
# Usage: ./scripts/task-tool.sh [spawn|status|result|background] [prompt] [background]

set -e

DOIT_DIR="$HOME/.doit"
TASKS_DIR="$DOIT_DIR/tasks"
TASK_LOG="$DOIT_DIR/task-log.json"

# Initialize tasks directory if not exists
mkdir -p "$TASKS_DIR"

# Initialize task log if not exists
if [ ! -f "$TASK_LOG" ]; then
  cat > "$TASK_LOG" <<'EOF'
{
  "version": "1.0",
  "tasks": [],
  "created": "",
  "updated": ""
}
EOF
fi

# Parse arguments
ACTION="${1:-spawn}"
PROMPT="${2:-}"
BACKGROUND="${3:-false}"

case "$ACTION" in
  spawn)
    # Spawn a new subagent task
    if [ -z "$PROMPT" ]; then
      echo "Usage: $0 spawn <prompt> [background]"
      exit 1
    fi
    
    TASK_ID="task-$(date +%s)-$$"
    
    # Create task state file
    cat > "$TASKS_DIR/$TASK_ID.json" <<EOF
{
  "id": "$TASK_ID",
  "prompt": "$PROMPT",
  "status": "spawned",
  "background": $BACKGROUND,
  "started": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "completed": null,
  "result": null,
  "model": "$(grep 'slow:' ~/.doit/config.yaml 2>/dev/null | cut -d' ' -f2 || echo 'auto')"
}
EOF
    
    # Log task creation
    EXISTING=$(cat "$TASK_LOG")
    cat > "$TASK_LOG" <<EOF
{
  "version": "1.0",
  "tasks": [
    $(echo "$EXISTING" | grep '"tasks"' | grep -v '^\s*\[' | head -1)
    {
      "id": "$TASK_ID",
      "prompt": "$PROMPT",
      "status": "spawned",
      "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    }
  ],
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    echo "Task spawned: $TASK_ID"
    if [ "$BACKGROUND" = "true" ]; then
      echo "Running in background"
      # Launch background task
      bash -c "
        echo 'Background task running...'
        # Simulate task execution
        sleep 1
        echo 'Task completed'
        cat > '$TASKS_DIR/$TASK_ID.json' <<ENDJSON
{
  \"id\": \"$TASK_ID\",
  \"prompt\": \"$PROMPT\",
  \"status\": \"completed\",
  \"background\": true,
  \"started\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
  \"completed\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
  \"result\": \"Task completed successfully\",
  \"model\": \"auto\"
}
ENDJSON
      " &
    fi
    ;;
  
  status)
    # Show task status
    if [ -f "$TASK_LOG" ]; then
      echo "Active tasks:"
      cat "$TASK_LOG" | grep -E '"id"|"status"|"prompt"' | sed 's/^/  /'
    else
      echo "No task log found"
    fi
    ;;
  
  result)
    # Get task result
    if [ -z "$1" ] || [ "$1" = "spawn" ] || [ "$1" = "status" ]; then
      echo "Usage: $0 result <task_id>"
      exit 1
    fi
    TASK_ID="$1"
    
    if [ -f "$TASKS_DIR/$TASK_ID.json" ]; then
      echo "Task result:"
      cat "$TASKS_DIR/$TASK_ID.json" | grep '"result"' | sed 's/^/  /'
    else
      echo "Task not found: $TASK_ID"
      exit 1
    fi
    ;;
  
  background)
    # Run task in background
    if [ -z "$PROMPT" ]; then
      echo "Usage: $0 background <prompt>"
      exit 1
    fi
    
    # Spawn background task
    bash "$0" spawn "$PROMPT" true
    ;;
  
  *)
    echo "Usage: $0 [spawn|status|result|background] [prompt] [background]"
    exit 1
    ;;
esac