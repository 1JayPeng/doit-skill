#!/bin/bash
# install_tavily.sh — Install Tavily (interactive API key flow)
install_tavily() {
  # Interactive flow - user must provide API key
  if [ -z "$TAVILY_API_KEY" ]; then
    echo "Please provide your Tavily API key (get one at https://tavily.com):"
    read -r TAVILY_API_KEY
  fi
  
  if [ -n "$TAVILY_API_KEY" ]; then
    echo "export TAVILY_API_KEY=\"$TAVILY_API_KEY\"" >> "$HOME/.bashrc"
    export TAVILY_API_KEY
    echo "Tavily configured."
  else
    echo "No API key provided - Tavily will be skipped"
    return 1
  fi
}
verify_tavily() {
  if [ -n "$TAVILY_API_KEY" ] || grep -q "TAVILY_API_KEY" "$HOME/.bashrc" 2>/dev/null; then
    echo "Tavily configured"
  fi
}
version_tavily() {
  echo "Tavily API"
}