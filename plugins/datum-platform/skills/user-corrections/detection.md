# Correction Detection

How agents detect and log user corrections during sessions.

## Detection Categories

Corrections are detected from two sources:

1. **Explicit signals** — User directly states a correction (high confidence)
2. **Implicit signals** — User action indicates a correction (medium confidence)

## Explicit Signal Detection

### High-Confidence Keywords

When user message contains these patterns, log an explicit correction:

| Pattern | Correction Type | Example |
|---------|-----------------|---------|
| "wrong", "incorrect", "that's not right" | `code_quality` | "That's wrong, the index should start at 1" |
| "no", "don't", "stop" | `approach_rejection` | "No, don't use that library" |
| "actually...", "instead..." | `approach_rejection` | "Actually, let's use the builder pattern instead" |
| "I didn't ask for..." | `expectation_mismatch` | "I didn't ask for tests yet" |
| "I prefer...", "I'd rather..." | `preference_conflict` | "I prefer explicit error handling over panic" |
| "let me clarify", "what I meant was" | `communication_gap` | "Let me clarify - I meant the storage interface" |
| "undo", "revert", "go back" | `approach_rejection` | "Undo that change" |
| "missing", "forgot", "you skipped" | `code_completeness` | "You forgot to add the error check" |

### Phrase Pattern Matching

```python
# Pseudocode for explicit detection
EXPLICIT_PATTERNS = {
    "approach_rejection": [
        r"(?:let's|let us) (?:try|use|do) .+ instead",
        r"(?:no|don't|stop),? (?:don't|do not|stop)",
        r"actually,? (?:let's|we should|I want)",
        r"(?:undo|revert|roll back) (?:that|this|the)",
    ],
    "expectation_mismatch": [
        r"I didn't (?:ask|want|need|request) (?:for|that|this)",
        r"(?:why did you|you shouldn't have) .+",
        r"that's not what I (?:meant|wanted|asked)",
    ],
    "code_quality": [
        r"(?:that's|this is|it's) (?:wrong|incorrect|broken|buggy)",
        r"(?:there's|you have) (?:a|an) (?:bug|error|mistake)",
        r"(?:fix|correct) (?:the|this|that)",
    ],
    "code_completeness": [
        r"(?:you|it) (?:forgot|missed|skipped|omitted)",
        r"(?:missing|need|add) .+ (?:handling|check|validation)",
        r"(?:what about|don't forget) .+",
    ],
    "preference_conflict": [
        r"I (?:prefer|like|want|always use)",
        r"(?:our|the|my) (?:convention|standard|pattern) is",
        r"(?:we|I) (?:usually|always|typically) .+ instead",
    ],
    "communication_gap": [
        r"(?:let me|to) clarify",
        r"what I (?:meant|mean|wanted) (?:was|is)",
        r"(?:I|you) misunderstood",
    ],
}
```

## Implicit Signal Detection

### Behavioral Patterns

| Signal | Correction Type | Detection Method |
|--------|-----------------|------------------|
| User edits code Claude just wrote | `code_quality` or `code_completeness` | File modified within 2 messages of Claude writing it |
| User re-requests same task differently | `communication_gap` | Similar task phrased differently |
| User manually adds what Claude skipped | `code_completeness` | User writes code in area Claude just modified |
| User undoes via git or IDE | `approach_rejection` | User runs `git checkout`, `git reset`, or editor undo |

### Edit Detection Logic

```python
# Pseudocode for implicit detection from edits
CORRECTION_WINDOW = timedelta(minutes=10)  # Time window for detecting related edits

def detect_implicit_correction(last_ai_action, user_action):
    if user_action.type == "file_edit":
        # User edited a file Claude recently modified
        if user_action.file in last_ai_action.files_modified:
            time_delta = user_action.timestamp - last_ai_action.timestamp

            # Within reasonable window (e.g., 2 conversation turns)
            if time_delta < CORRECTION_WINDOW:
                # Analyze the diff
                if is_bug_fix(user_action.diff):
                    return CorrectionType.CODE_QUALITY
                elif is_addition(user_action.diff):
                    return CorrectionType.CODE_COMPLETENESS
                elif is_style_change(user_action.diff):
                    return CorrectionType.PREFERENCE_CONFLICT

    return None
```

### Re-request Detection

```python
# Detect when user rephrases the same request
def detect_rerequest(current_request, previous_requests):
    for prev in previous_requests[-3:]:  # Check last 3 requests
        similarity = semantic_similarity(current_request, prev.request)
        if similarity > 0.7:  # High semantic overlap
            if prev.was_completed:  # Claude thought it was done
                return CorrectionType.COMMUNICATION_GAP
    return None
```

## When to Log

### DO Log

- Clear explicit correction signals (keywords match)
- User edits code Claude wrote in the same session
- User requests undo/revert of Claude's changes
- User rephrases a request Claude already "completed"
- User adds code Claude explicitly skipped
- User expresses preference after Claude chose differently

### DO NOT Log

- User asks for follow-up features (not a correction)
- User provides new information that changes requirements (requirements evolution)
- User corrects their own previous input (not correcting Claude)
- Minor typo fixes in comments/strings
- User explores alternatives (brainstorming, not rejection)
- User asks clarifying questions (gathering info, not correcting)

## Logging Format

When a correction is detected, append to `.claude/user-corrections.jsonl`:

```json
{
  "date": "YYYY-MM-DD",
  "timestamp": "ISO-8601 timestamp",
  "agent": "current-agent-name",
  "session_id": "current-session-uuid",
  "correction_type": "detected-type",
  "ai_action": {
    "summary": "Brief description of what Claude did",
    "tool_used": "Tool name if applicable",
    "file": "file/path:line if applicable"
  },
  "user_correction": {
    "summary": "Brief description of user's correction",
    "verbatim": "Exact user text for explicit corrections"
  },
  "pattern_inferred": "pattern-name-if-obvious",
  "pattern_confidence": "high|medium|low",
  "context": {
    "task": "Current task description",
    "feature_id": "feat-XXX if pipeline",
    "service": "service-name"
  },
  "severity": "high|medium|low",
  "source": "explicit|implicit"
}
```

## Severity Assessment

### High Severity

- Correction blocked progress entirely
- User had to undo significant work
- Bug would have caused runtime errors
- Security or correctness issue

### Medium Severity

- Required user intervention to fix
- Caused confusion or wasted time
- Approach was suboptimal but functional

### Low Severity

- Preference or style difference
- Minor adjustment
- Optional improvement

## Confidence Assessment

### High Confidence (explicit + clear pattern)

- Clear explicit keyword match
- User provided specific correction
- Pattern is well-established

### Medium Confidence (implicit or unclear)

- Behavioral signal without explicit statement
- Pattern is plausible but not certain
- Could be requirements evolution vs. correction

### Low Confidence (uncertain)

- Edge case detection
- Ambiguous user intent
- First occurrence of pattern

## Integration in Agent Workflow

Add this section to agent prompts:

```markdown
## Correction Detection

During your session, watch for user corrections:

1. **Explicit signals**: Keywords like "wrong", "actually", "instead", "I prefer"
2. **Implicit signals**: User edits your code, re-requests differently, adds missing pieces

When you detect a correction:
1. Acknowledge the correction naturally
2. Apply the corrected approach
3. Log to `.claude/user-corrections.jsonl` if it represents a learnable pattern

Example log entry:
```json
{
  "date": "2025-01-15",
  "timestamp": "2025-01-15T10:30:00Z",
  "agent": "api-dev",
  "correction_type": "approach_rejection",
  "ai_action": {"summary": "Used direct SQL instead of storage interface"},
  "user_correction": {"summary": "User requested storage interface pattern", "verbatim": "Let's use the storage interface like other resources"},
  "pattern_inferred": "use-existing-patterns",
  "pattern_confidence": "high",
  "severity": "high",
  "source": "explicit"
}
```

Focus on corrections that represent learnable patterns, not one-off adjustments.
```

## Pattern Extraction

When `/evolve` runs, it:

1. Loads `.claude/user-corrections.jsonl`
2. Groups corrections by `pattern_inferred`
3. Weights by source (`explicit` = 1.0, `implicit` = 0.8)
4. Calculates confidence including source quality score
5. Promotes high-confidence patterns to runbooks

See `learning-engine/analysis.md` for the full confidence calculation.
