#!/bin/bash
# doit-skill worker process support for OMP
# Usage: ./scripts/worker.sh [start|stop|status|submit|result] [command/prompt]

set -e

DOIT_DIR="$HOME/.doit"
WORKER_DIR="$DOIT_DIR/workers"
WORKER_LOG="$DOIT_DIR/worker-log.json"
WORKER_STATE="$DOIT_DIR/worker-state.json"

# Initialize worker directory if not exists
mkdir -p "$WORKER_DIR"

# Initialize worker log if not exists
if [ ! -f "$WORKER_LOG" ]; then
  cat > "$WORKER_LOG" <<'EOF'
{
  "version": "1.0",
  "workers": [],
  "created": "",
  "updated": ""
}
EOF
fi

# Initialize worker state if not exists
if [ ! -f "$WORKER_STATE" ]; then
  cat > "$WORKER_STATE" <<'EOF'
{
  "version": "1.0",
  "active": false,
  "pid": null,
  "started": null,
  "created": "",
  "updated": ""
}
EOF
fi

# Parse arguments
ACTION="${1:-status}"
COMMAND_OR_PROMPT="${2:-}"

case "$ACTION" in
  start)
    # Start worker process
    echo "Starting worker process..."
    
    # Check if worker is already running
    if grep -q '"active": true' "$WORKER_STATE"; then
      echo "Worker already running (PID: $(grep '"pid":' "$WORKER_STATE" | cut -d' ' -f2 | tr -d ', '))"
      exit 0
    fi
    
    # Create worker script
    WORKER_SCRIPT="$WORKER_DIR/worker-$$"
    cat > "$WORKER_SCRIPT" <<'PYEOF'
#!/usr/bin/env python3
"""doit-skill worker process for OMP"""
import json
import os
import sys
import time
from datetime import datetime

class Worker:
    def __init__(self):
        self.doit_dir = os.path.expanduser("~/.doit")
        self.state_file = os.path.join(self.doit_dir, "worker-state.json")
        self.log_file = os.path.join(self.doit_dir, "worker-log.json")
        self.tasks_dir = os.path.join(self.doit_dir, "tasks")
        self.running = True
        self.tasks = []
    
    def start(self):
        """Start the worker loop"""
        self.update_state(active=True)
        print("Worker started", flush=True)
        
        while self.running:
            # Check for new tasks
            new_tasks = self.load_tasks()
            for task in new_tasks:
                if task not in self.tasks:
                    self.tasks.append(task)
                    self.execute_task(task)
            
            # Check for state changes
            self.update_state(active=True)
            time.sleep(1)
    
    def execute_task(self, task):
        """Execute a single task"""
        task_id = task.get("id", "unknown")
        prompt = task.get("prompt", "")
        print(f"Executing task: {task_id}", flush=True)
        
        # Simulate task execution
        time.sleep(1)
        
        # Update task status
        task["status"] = "completed"
        task["completed"] = datetime.utcnow().isoformat() + "Z"
        task["result"] = "Task completed successfully"
        
        # Save task
        task_file = os.path.join(self.tasks_dir, f"{task_id}.json")
        with open(task_file, 'w') as f:
            json.dump(task, f, indent=2)
        
        print(f"Task completed: {task_id}", flush=True)
    
    def load_tasks(self):
        """Load pending tasks from task log"""
        tasks = []
        log_file = self.log_file
        if os.path.exists(log_file):
            with open(log_file, 'r') as f:
                data = json.load(f)
                tasks = data.get("tasks", [])
        return tasks
    
    def update_state(self, **kwargs):
        """Update worker state"""
        state = {
            "version": "1.0",
            "active": True,
            "pid": os.getpid(),
            "started": datetime.utcnow().isoformat() + "Z",
            "updated": datetime.utcnow().isoformat() + "Z"
        }
        state.update(kwargs)
        
        with open(self.state_file, 'w') as f:
            json.dump(state, f, indent=2)
    
    def stop(self):
        """Stop the worker"""
        self.running = False
        self.update_state(active=False)
        print("Worker stopped", flush=True)

if __name__ == "__main__":
    worker = Worker()
    
    # Handle graceful shutdown
    import signal
    def signal_handler(signum, frame):
        worker.stop()
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Start worker loop
    worker.start()
PYEOF
    
    chmod +x "$WORKER_SCRIPT"
    
    # Start worker in background
    "$WORKER_SCRIPT" &
    WORKER_PID=$!
    
    # Update worker state
    cat > "$WORKER_STATE" <<EOF
{
  "version": "1.0",
  "active": true,
  "pid": $WORKER_PID,
  "started": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    # Log worker start
    EXISTING=$(cat "$WORKER_LOG")
    cat > "$WORKER_LOG" <<EOF
{
  "version": "1.0",
  "workers": [
    $(echo "$EXISTING" | grep '"workers"' | grep -v '^\s*\[' | head -1)
    {
      "pid": $WORKER_PID,
      "started": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
      "status": "running"
    }
  ],
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    echo "Worker started (PID: $WORKER_PID)"
    ;;
  
  stop)
    # Stop worker process
    if grep -q '"active": true' "$WORKER_STATE"; then
      PID=$(grep '"pid":' "$WORKER_STATE" | cut -d' ' -f2 | tr -d ', ')
      
      if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        kill "$PID" 2>/dev/null || true
        sleep 1
        
        if kill -0 "$PID" 2>/dev/null; then
          kill -9 "$PID" 2>/dev/null || true
        fi
        
        echo "Worker stopped (PID: $PID)"
      else
        echo "Worker not found"
      fi
    else
      echo "Worker not running"
    fi
    ;;
  
  status)
    # Show worker status
    if grep -q '"active": true' "$WORKER_STATE"; then
      PID=$(grep '"pid":' "$WORKER_STATE" | cut -d' ' -f2 | tr -d ', ')
      STARTED=$(grep '"started":' "$WORKER_STATE" | head -1 | cut -d' ' -f2 | tr -d '"' | tr -d ',')
      
      echo "Worker status:"
      echo "  Active: true"
      echo "  PID: $PID"
      echo "  Started: $STARTED"
    else
      echo "Worker status:"
      echo "  Active: false"
    fi
    ;;
  
  submit)
    # Submit task to worker
    if [ -z "$COMMAND_OR_PROMPT" ]; then
      echo "Usage: $0 submit <prompt>"
      exit 1
    fi
    
    TASK_ID="task-$(date +%s)-$$"
    
    # Create task
    cat > "$DOIT_DIR/tasks/$TASK_ID.json" <<EOF
{
  "id": "$TASK_ID",
  "prompt": "$COMMAND_OR_PROMPT",
  "status": "pending",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    # Add to task log
    EXISTING=$(cat "$WORKER_LOG")
    cat > "$WORKER_LOG" <<EOF
{
  "version": "1.0",
  "workers": [
    $(echo "$EXISTING" | grep '"workers"' | grep -v '^\s*\[' | head -1)
  ],
  "tasks": [
    {
      "id": "$TASK_ID",
      "prompt": "$COMMAND_OR_PROMPT",
      "status": "pending",
      "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    }
  ],
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    echo "Task submitted: $TASK_ID"
    ;;
  
  result)
    # Get task result
    if [ -z "$COMMAND_OR_PROMPT" ]; then
      echo "Usage: $0 result <task_id>"
      exit 1
    fi
    TASK_ID="$COMMAND_OR_PROMPT"
    
    if [ -f "$DOIT_DIR/tasks/$TASK_ID.json" ]; then
      echo "Task result:"
      cat "$DOIT_DIR/tasks/$TASK_ID.json" | grep '"result"' | sed 's/^/  /'
    else
      echo "Task not found: $TASK_ID"
      exit 1
    fi
    ;;
  
  *)
    echo "Usage: $0 [start|stop|status|submit|result] [command/prompt]"
    exit 1
    ;;
esac