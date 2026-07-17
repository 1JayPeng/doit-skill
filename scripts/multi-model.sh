#!/bin/bash
# doit-skill multi-model configuration for OMP
# Usage: ./scripts/multi-model.sh [--smol <model>] [--slow <model>] [--plan <model>] [--check]

set -e

CONFIG_FILE="$HOME/.doit/config.yaml"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --smol)
      i=$((i + 1))
      MODEL_SMOL="${!i}"
      shift
      ;;
    --slow)
      i=$((i + 1))
      MODEL_SLOW="${!i}"
      shift
      ;;
    --plan)
      i=$((i + 1))
      MODEL_PLAN="${!i}"
      shift
      ;;
    --check)
      CHECK_MODE=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

if [ "$CHECK_MODE" = true ]; then
  # Check mode: verify model configuration
  if [ -f "$CONFIG_FILE" ]; then
    _model_smol=$(grep -A1 'smol:' "$CONFIG_FILE" 2>/dev/null | grep -v 'smol:' | awk '{print $2}' || echo "")
    _model_slow=$(grep -A1 'slow:' "$CONFIG_FILE" 2>/dev/null | grep -v 'slow:' | awk '{print $2}' || echo "")
    _model_plan=$(grep -A1 'plan:' "$CONFIG_FILE" 2>/dev/null | grep -v 'plan:' | awk '{print $2}' || echo "")
    
    if [ -n "$_model_smol" ]; then
      echo "  ✅ smol model: $_model_smol"
    else
      echo "  ℹ️  smol model not configured (optional)"
    fi
    if [ -n "$_model_slow" ]; then
      echo "  ✅ slow model: $_model_slow"
    else
      echo "  ℹ️  slow model not configured (optional)"
    fi
    if [ -n "$_model_plan" ]; then
      echo "  ✅ plan model: $_model_plan"
    else
      echo "  ℹ️  plan model not configured (optional)"
    fi
  else
    echo "  ℹ️  Config file not found — run setup.sh first"
  fi
  exit 0
fi

# Set mode: update model configuration
mkdir -p "$HOME/.doit"

if [ -f "$CONFIG_FILE" ]; then
  # Update existing config
  if [ -n "$MODEL_SMOL" ]; then
    if grep -q 'models:' "$CONFIG_FILE" 2>/dev/null; then
      sed -i "s/^  smol: .*/  smol: \"$MODEL_SMOL\"/" "$CONFIG_FILE"
    else
      echo "models:" >> "$CONFIG_FILE"
      echo "  smol: \"$MODEL_SMOL\"" >> "$CONFIG_FILE"
    fi
    echo "  Set smol model: $MODEL_SMOL"
  fi
  
  if [ -n "$MODEL_SLOW" ]; then
    if grep -q 'models:' "$CONFIG_FILE" 2>/dev/null; then
      sed -i "s/^  slow: .*/  slow: \"$MODEL_SLOW\"/" "$CONFIG_FILE"
    else
      echo "models:" >> "$CONFIG_FILE"
      echo "  slow: \"$MODEL_SLOW\"" >> "$CONFIG_FILE"
    fi
    echo "  Set slow model: $MODEL_SLOW"
  fi
  
  if [ -n "$MODEL_PLAN" ]; then
    if grep -q 'models:' "$CONFIG_FILE" 2>/dev/null; then
      sed -i "s/^  plan: .*/  plan: \"$MODEL_PLAN\"/" "$CONFIG_FILE"
    else
      echo "models:" >> "$CONFIG_FILE"
      echo "  plan: \"$MODEL_PLAN\"" >> "$CONFIG_FILE"
    fi
    echo "  Set plan model: $MODEL_PLAN"
  fi
else
  # Create new config with model settings
  cat > "$CONFIG_FILE" <<CONFIG_EOF
subagent:
  enabled: true
auto_commit:
  enabled: false
doc-capture:
  enabled: true
headroom:
  proxy:
    enabled: true
    port: 8787
commit:
  branch: branch
models:
  smol: "${MODEL_SMOL:-}"
  slow: "${MODEL_SLOW:-}"
  plan: "${MODEL_PLAN:-}"
CONFIG_EOF
  echo "  Created $CONFIG_FILE with model settings"
fi

echo "  Model configuration updated"