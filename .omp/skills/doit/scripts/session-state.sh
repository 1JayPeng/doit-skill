#!/bin/bash
# doit-skill session state management for OMP
# Usage: ./scripts/session-state.sh [save|load|status|continue]

set -e

DOIT_DIR="$HOME/.doit"
SESSION_FILE="$DOIT_DIR/session-state.json"
CURRENT_PHASE="0"

# Parse arguments
case "${1:-status}" in
  save)
    # Save current session state
    CURRENT_PHASE="${2:-$CURRENT_PHASE}"
    CURRENT_TASK="${3:-$(grep 'current_task:' "$SESSION_FILE" 2>/dev/null | head -1 | cut -d' ' -f2 || echo '')}"
    
    cat > "$SESSION_FILE" <<EOF
{
  "version": "1.0",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "phase": $CURRENT_PHASE,
  "current_task": "$CURRENT_TASK",
  "status": "in_progress",
  "omp_session_id": "${OMP_SESSION_ID:-unknown}",
  "resume_info": "Resume from Phase $CURRENT_PHASE"
}
EOF
    
    echo "Session state saved to $SESSION_FILE"
    ;;
  
  load)
    # Load session state
    if [ -f "$SESSION_FILE" ]; then
      CURRENT_PHASE=$(grep '"phase":' "$SESSION_FILE" | cut -d' ' -f2 | tr -d ',')
      CURRENT_TASK=$(grep '"current_task":' "$SESSION_FILE" | cut -d' ' -f2 | tr -d '"' | tr -d ',')
      CURRENT_STATUS=$(grep '"status":' "$SESSION_FILE" | cut -d' ' -f2 | tr -d '"' | tr -d ',')
      OMP_SESSION_ID=$(grep '"omp_session_id":' "$SESSION_FILE" | cut -d' ' -f2 | tr -d '"' | tr -d ',')
      
      echo "Session loaded:"
      echo "  Phase: $CURRENT_PHASE"
      echo "  Task: $CURRENT_TASK"
      echo "  Status: $CURRENT_STATUS"
      echo "  OMP Session: $OMP_SESSION_ID"
    else
      echo "No session state found"
      exit 1
    fi
    ;;
  
  status)
    # Show current session status
    if [ -f "$SESSION_FILE" ]; then
      CURRENT_PHASE=$(grep '"phase":' "$SESSION_FILE" | cut -d' ' -f2 | tr -d ',')
      CURRENT_TASK=$(grep '"current_task":' "$SESSION_FILE" | cut -d' ' -f2 | tr -d '"' | tr -d ',')
      CURRENT_STATUS=$(grep '"status":' "$SESSION_FILE" | cut -d' ' -f2 | tr -d '"' | tr -d ',')
      
      echo "Current session state:"
      echo "  Phase: $CURRENT_PHASE"
      echo "  Task: $CURRENT_TASK"
      echo "  Status: $CURRENT_STATUS"
    else
      echo "No active session"
    fi
    ;;
  
  continue)
    # Continue from saved session
    if [ -f "$SESSION_FILE" ]; then
      CURRENT_PHASE=$(grep '"phase":' "$SESSION_FILE" | cut -d' ' -f2 | tr -d ',')
      CURRENT_TASK=$(grep '"current_task":' "$SESSION_FILE" | cut -d' ' -f2 | tr -d '"' | tr -d ',')
      
      echo "Continuing from Phase $CURRENT_PHASE: $CURRENT_TASK"
      
      # Export for omp --continue
      export OMP_SESSION_CONTINUE=true
      export OMP_CONTINUE_PHASE=$CURRENT_PHASE
      export OMP_CONTINUE_TASK=$CURRENT_TASK
      
      # Update status to resumed
      sed -i "s/\"status\": .*/\"status\": \"resumed\",/" "$SESSION_FILE"
      sed -i "s/\"updated\": .*/\"updated\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",/" "$SESSION_FILE"
      
      echo "Session resumed at Phase $CURRENT_PHASE"
    else
      echo "No session to continue"
      exit 1
    fi
    ;;
  
  *)
    echo "Usage: $0 [save|load|status|continue] [phase] [task]"
    exit 1
    ;;
esac