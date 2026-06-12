# Knowledge Injection — Phase 1/2 Integration

## Purpose

Inject relevant past knowledge into Phase 1 (Spec) and Phase 2 (Plan) to prevent repeating mistakes and accelerate decision-making.

## When to Inject

**Phase 1 (Spec) — Before grill questions:**
- Search for similar past features/bugs
- Surface decisions that might apply
- Warn about known pitfalls

**Phase 2 (Plan) — Before impact analysis:**
- Search for similar code patterns
- Surface integration points from past experience
- Suggest implementation approaches that worked

## Injection Process

### Step 1: Generate Search Query

Extract keywords from user's request:
- **Technical terms**: auth, API, database, cache, middleware
- **Action verbs**: add, fix, refactor, implement
- **Domain terms**: Project-specific vocabulary

Search query = `"<user request keywords>" <project> <type>`

### Step 2: Search MemPalace

Search MemPalace as the primary knowledge source:

**MemPalace (Primary):**
```
mempalace_search query="<search query>" wing="<project>" room="knowledge_distillation" limit=5
mempalace_search query="<search query>" wing="<project>" limit=3
```

**Fallback (if MemPalace unavailable):**
```bash
# Search .doit/knowledge/ for matching records
grep -r "<keyword>" .doit/knowledge/*.json 2>/dev/null | head -20
```

### Step 3: Rank and Deduplicate

Rank results:
1. **Semantic similarity** — from embedding search
2. **Time decay** — recent sessions weighted higher: `score *= exp(-0.1 * days_since)`
3. **Type match** — same request type (F/B/S) gets bonus
4. **Status** — success records ranked higher than failed
5. **Confidence** — higher confidence records ranked higher

Remove duplicates (same session ID from multiple searches).

### Step 4: Select Top-3

Choose top-3 most relevant past sessions. For each, extract:
- **Summary**: What was done
- **Key decisions**: Choices made with rationale
- **Errors**: Pitfalls encountered (with resolutions)
- **Code patterns**: Reusable patterns applied

### Step 5: Inject into Context

Format and inject into conversation context:

```
[KNOWLEDGE INJECTION] Found 3 relevant past sessions:

1. [2026-06-05] "Add user authentication with OAuth2" (Type: F, Status: success)
   Summary: Implemented JWT-based auth with httpOnly cookies
   Key decision: JWT stateless -> mobile compatible, no server state
   Error avoided: Session token storage failed compliance -> used httpOnly cookies
   Pattern: Auth middleware with token validation chain

2. [2026-06-03] "Fix login page crash on empty email" (Type: B, Status: success)
   Summary: Added input validation for email field
   Key decision: Client + server validation -> defense in depth
   Error: Initial fix only validated client-side -> bypassed

3. [2026-05-28] "Add API rate limiting" (Type: F, Status: partial)
   Summary: Implemented rate limiter middleware (incomplete)
   Key decision: Redis-based rate limit -> distributed, persistent
   Warning: Session ended before full implementation — may need different approach
```

### Step 6: Use in Grill

When asking grill questions, reference past knowledge:
- "Based on past session X, we chose JWT for auth. Should we use the same approach here, or has the context changed?"
- "Past session Y encountered database migration conflicts. Should we add migration locks?"

## Injection Quality Guidelines

**Inject when:**
- Past session has high confidence score (>0.7)
- Semantic similarity is high (>0.8)
- Past session completed successfully
- Error patterns are relevant to current request

**De-prioritize when:**
- Past session is old (>90 days) — time decay
- Past session failed without resolution
- Low confidence score (<0.5)
- Different project context (cross-project transfer needs caution)

## Failed Session Warnings

When a past session failed with relevant errors, inject as a warning:

```
[KNOWLEDGE WARNING] Similar approach failed in session 2026-06-03:
  Error: Database migration conflict with concurrent attempts
  Root cause: No migration locking mechanism
  Lesson: Use migration locks or serialize migrations
  Status: Not resolved — session ended
```

This helps the user avoid known pitfalls without blocking the workflow.

## Graceful Degradation

| Available Tools | Behavior |
|----------------|----------|
| MemPalace | MemPalace search |
| None | Filesystem search (.doit/knowledge/) |

If no knowledge found:
```
[KNOWLEDGE INJECTION] No relevant past sessions found. Starting fresh.
```

## Configuration

Control injection behavior via `.doit/config.yaml`:

```yaml
knowledge:
  injection:
    enabled: true            # Enable/disable knowledge injection
    phases: [1, 2]          # Which phases to inject
    max_results: 3          # Top-N results to show
    min_confidence: 0.5     # Minimum confidence to inject
    time_decay_days: 10     # Days for score to halve
    include_failed: true    # Include failed sessions as warnings
    cross_project: false    # Search across all projects (false = current only)
    source: mempalace       # Primary search source (mempalace | filesystem)
```
