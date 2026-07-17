#!/bin/bash
# doit-skill workflow state persistence for OMP
# Usage: ./scripts/workflow-state.sh [save|load|status|persist] [phase] [data]

set -e

DOIT_DIR="$HOME/.doit"
WORKFLOW_STATE="$DOIT_DIR/workflow-state.json"

# Initialize workflow state if not exists
if [ ! -f "$WORKFLOW_STATE" ]; then
  cat > "$WORKFLOW_STATE" <<'EOF'
{
  "version": "1.0",
  "phases": {},
  "current_phase": null,
  "created": "",
  "updated": ""
}
EOF
fi

# Parse arguments
ACTION="${1:-status}"
PHASE="${2:-}"
DATA="${3:-}"

case "$ACTION" in
  save)
    # Save workflow state for a phase
    if [ -z "$PHASE" ]; then
      echo "Usage: $0 save <phase> [data]"
      exit 1
    fi
    
    # Read existing state
    EXISTING=$(cat "$WORKFLOW_STATE")
    
    # Extract phases
    PHASES=$(echo "$EXISTING" | grep -A1000 '"phases":' | sed 's/.*"phases": \[//;s/\].*//')
    
    # Add or update phase
    if echo "$PHASES" | grep -q "\"$PHASE\""; then
      # Update existing phase
      PHASES=$(echo "$PHASES" | sed "s/\"$PHASE\":.*/\"$PHASE\": {\"data\": \"$DATA\", \"updated\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"},/g")
    else
      # Add new phase
      PHASES="$PHASES,{\"$PHASE\": {\"data\": \"$DATA\", \"updated\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}}"
    fi
    
    # Write updated state
    cat > "$WORKFLOW_STATE" <<EOF
{
  "version": "1.0",
  "phases": [$PHASES],
  "current_phase": "$PHASE",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    echo "Phase $PHASE saved"
    ;;
  
  load)
    # Load workflow state for a phase
    if [ -z "$PHASE" ]; then
      echo "Usage: $0 load <phase>"
      exit 1
    fi
    
    if [ -f "$WORKFLOW_STATE" ]; then
      # Extract phase data
      RESULT=$(cat "$WORKFLOW_STATE" | grep -A10 "\"$PHASE\":" | head -5)
      
      if [ -n "$RESULT" ]; then
        echo "Phase $PHASE state:"
        echo "$RESULT" | sed 's/^/  /'
      else
        echo "Phase $PHASE not found"
        exit 1
      fi
    else
      echo "No workflow state found"
      exit 1
    fi
    ;;
  
  status)
    # Show workflow status
    if [ -f "$WORKFLOW_STATE" ]; then
      CURRENT_PHASE=$(grep '"current_phase":' "$WORKFLOW_STATE" | cut -d' ' -f2 | tr -d '"' | tr -d ',')
      UPDATED=$(grep '"updated":' "$WORKFLOW_STATE" | tail -1 | cut -d' ' -f2 | tr -d '"' | tr -d ',')
      
      echo "Workflow state:"
      echo "  Current phase: $CURRENT_PHASE"
      echo "  Last updated: $UPDATED"
    else
      echo "No workflow state found"
    fi
    ;;
  
  persist)
    # Persist current session to workflow
    if [ -f "$DOIT_DIR/session-state.json" ]; then
      CURRENT_PHASE=$(grep '"phase":' "$DOIT_DIR/session-state.json" | cut -d' ' -f2 | tr -d ',')
      CURRENT_TASK=$(grep '"current_task":' "$DOIT_DIR/session-state.json" | cut -d' ' -f2 | tr -d '"' | tr -d ',')
      
      # Save to workflow state
      bash "$0" save "$CURRENT_PHASE" "Task: $CURRENT_TASK"
      
      echo "Session persisted to workflow state"
    else
      echo "No session state to persist"
      exit 1
    fi
    ;;
  
  *)
    echo "Usage: $0 [save|load|status|persist] [phase] [data]"
    exit 1
    ;;
esac