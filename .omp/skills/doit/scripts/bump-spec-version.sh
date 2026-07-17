#!/bin/bash
# Bump spec version number.
# Usage: bump-spec-version.sh [.spec/current.md]
# Increments version field in YAML frontmatter.
# Creates v1 if not present.

SPEC_FILE="${1:-.spec/current.md}"

if [ ! -f "$SPEC_FILE" ]; then
  echo "Spec file not found: $SPEC_FILE" >&2
  exit 1
fi

# Extract current version (vN)
current_version=$(grep -E '^version: v[0-9]+' "$SPEC_FILE" | head -1 | sed 's/version: v//')

if [ -z "$current_version" ]; then
  # Create new spec with v1
  echo "Creating new spec with version v1"
  cat > "$SPEC_FILE" <<EOF
---
version: v1
feature: [name]
created: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
updated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
---

# Feature: [name]

## Branch
\`feature/[short-name]\`

## Description
[What + why, not how]

## Acceptance Criteria
| ID | Description | Status | Blocked By |
|----|-------------|--------|------------|
| REQ-001 | ... | TODO | - |

## E2E Scenario
[Full user journey from start to finish]
EOF
  echo "Created $SPEC_FILE"
  exit 0
fi

# Increment version
new_version=$((current_version + 1))

# Update version field
sed -i "s/^version: v[0-9]*/version: v$new_version/" "$SPEC_FILE"

# Update timestamp if present
if grep -q '^updated:' "$SPEC_FILE"; then
  sed -i "s/^updated: .*/updated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")/" "$SPEC_FILE"
else
  # Add updated field after version
  sed -i "/^version: v$a_new_version/a\\updated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$SPEC_FILE"
fi

echo "Bumped version: v$current_version -> v$new_version"