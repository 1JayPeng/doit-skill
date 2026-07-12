#!/usr/bin/env python3
"""Configure Tavily MCP for AI coding CLI."""

import json
import os
import sys


def remove_tavily(config_path: str) -> None:
    """Remove tavily entry from JSON config."""
    try:
        with open(config_path) as f:
            d = json.load(f)
        mcp = d.get('mcp', {})
        if 'tavily' in mcp:
            del mcp['tavily']
            with open(config_path, 'w') as f:
                json.dump(d, f, indent=2)
    except Exception:
        pass


def write_tavily_json(config_path: str, key: str) -> None:
    """Write tavily config to JSON file."""
    try:
        with open(config_path) as f:
            d = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        d = {}
    if 'mcp' not in d:
        d['mcp'] = {}
    d['mcp']['tavily'] = {
        'transport': 'http',
        'url': f'https://mcp.tavily.com/mcp/?tavilyApiKey={key}'
    }
    with open(config_path, 'w') as f:
        json.dump(d, f, indent=2)


def main():
    config_path = os.environ.get('CONFIG_PATH', '')
    tavily_key = os.environ.get('TAVILY_KEY', '')
    action = sys.argv[1] if len(sys.argv) > 1 else 'write'

    if action == 'remove':
        remove_tavily(config_path)
    elif action == 'write' or action == 'write-json':
        write_tavily_json(config_path, tavily_key)


if __name__ == '__main__':
    main()