#!/bin/bash
# doit-skill todo tool for OMP integration
# Usage: ./scripts/todo-tool.sh [init|start|done|view|append|drop|rm] [phase] [task]

set -e

DOIT_DIR="$HOME/.doit"
TODOS_FILE="$DOIT_DIR/todos.json"

# Initialize todos file if not exists
if [ ! -f "$TODOS_FILE" ]; then
  cat > "$TODOS_FILE" <<'EOF'
{
  "version": "1.0",
  "tasks": [],
  "current_phase": null,
  "created": "",
  "updated": ""
}
EOF
fi

# Parse arguments
ACTION="${1:-view}"

case "$ACTION" in
  init)
    PHASE="${2:-}"
    TASK="${3:-}"
    if [ -z "$PHASE" ] || [ -z "$TASK" ]; then
      echo "Usage: $0 init <phase> <task>"
      exit 1
    fi
    
    cat > "$TODOS_FILE" <<EOF
{
  "version": "1.0",
  "tasks": [
    {
      "phase": "$PHASE",
      "task": "$TASK",
      "status": "pending",
      "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    }
  ],
  "current_phase": "$PHASE",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    echo "Task initialized: [$PHASE] $TASK"
    ;;
  
  start)
    TASK="${2:-}"
    if [ -z "$TASK" ]; then
      echo "Usage: $0 start <task>"
      exit 1
    fi
    
    python3 - "$TODOS_FILE" "$TASK" << 'PYEOF'
import json, sys
todos_file = sys.argv[1]
task_name = sys.argv[2]
with open(todos_file, 'r') as f:
    data = json.load(f)
for task in data['tasks']:
    if task['task'] == task_name:
        task['status'] = 'in_progress'
data['updated'] = __import__('datetime').datetime.utcnow().isoformat() + 'Z'
with open(todos_file, 'w') as f:
    json.dump(data, f, indent=2)
PYEOF
    
    echo "Task started: $TASK"
    ;;
  
  done)
    TASK="${2:-}"
    if [ -z "$TASK" ]; then
      echo "Usage: $0 done <task>"
      exit 1
    fi
    
    python3 - "$TODOS_FILE" "$TASK" << 'PYEOF'
import json, sys
todos_file = sys.argv[1]
task_name = sys.argv[2]
with open(todos_file, 'r') as f:
    data = json.load(f)
for task in data['tasks']:
    if task['task'] == task_name:
        task['status'] = 'completed'
data['updated'] = __import__('datetime').datetime.utcnow().isoformat() + 'Z'
with open(todos_file, 'w') as f:
    json.dump(data, f, indent=2)
PYEOF
    
    echo "Task completed: $TASK"
    ;;
  
  view)
    if [ -f "$TODOS_FILE" ]; then
      echo "Current todos:"
      python3 - "$TODOS_FILE" << 'PYEOF'
import json, sys
todos_file = sys.argv[1]
with open(todos_file, 'r') as f:
    data = json.load(f)
for task in data['tasks']:
    print(f'  [{task["status"]}] {task["task"]} ({task["phase"]})')
PYEOF
    else
      echo "No todos file found"
    fi
    ;;
  
  append)
    PHASE="${2:-}"
    TASK="${3:-}"
    if [ -z "$PHASE" ] || [ -z "$TASK" ]; then
      echo "Usage: $0 append <phase> <task>"
      exit 1
    fi
    
    python3 - "$TODOS_FILE" "$PHASE" "$TASK" << 'PYEOF'
import json, sys
todos_file = sys.argv[1]
phase = sys.argv[2]
task_name = sys.argv[3]
with open(todos_file, 'r') as f:
    data = json.load(f)
data['tasks'].append({
    'phase': phase,
    'task': task_name,
    'status': 'pending',
    'created': __import__('datetime').datetime.utcnow().isoformat() + 'Z'
})
data['current_phase'] = phase
data['updated'] = __import__('datetime').datetime.utcnow().isoformat() + 'Z'
with open(todos_file, 'w') as f:
    json.dump(data, f, indent=2)
PYEOF
    
    echo "Task appended: [$PHASE] $TASK"
    ;;
  
  drop)
    TASK="${2:-}"
    if [ -z "$TASK" ]; then
      echo "Usage: $0 drop <task>"
      exit 1
    fi
    
    python3 - "$TODOS_FILE" "$TASK" << 'PYEOF'
import json, sys
todos_file = sys.argv[1]
task_name = sys.argv[2]
with open(todos_file, 'r') as f:
    data = json.load(f)
data['tasks'] = [t for t in data['tasks'] if t['task'] != task_name]
data['updated'] = __import__('datetime').datetime.utcnow().isoformat() + 'Z'
with open(todos_file, 'w') as f:
    json.dump(data, f, indent=2)
PYEOF
    
    echo "Task dropped: $TASK"
    ;;
  
  rm)
    cat > "$TODOS_FILE" <<EOF
{
  "version": "1.0",
  "tasks": [],
  "current_phase": null,
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    echo "All tasks removed"
    ;;
  
  *)
    echo "Usage: $0 [init|start|done|view|append|drop|rm] [phase] [task]"
    exit 1
    ;;
esac