# CAM Changelog

All notable changes to the CAM (Continuous Architectural Memory) system are documented here.

**Scope**: This changelog tracks changes to:
- `CLAUDE.md` - Protocol specification
- `~/.claude/hooks/*` - Hook scripts
- `~/.claude/settings.json` - Hook registration
- `cam_core.py` - Core library
- `cam.sh` - CLI wrapper

**Format**: [Semantic Versioning](https://semver.org/)

---

## [1.8.0] - 2025-12-08

### Added - Phase 10: Architectural Memory Evolution Framework

Complete MVP architecture for next-generation CAM system addressing context amnesia and enabling declarative LLM development patterns.

#### Phase 1: Extending CAM's Data Model
- **4-Layer Semantic Architecture**: Enhanced embeddings (importance_tier) + relationships (causal/temporal/semantic) + decisions (rationale + alternatives) + invariants (constraints)
- **Importance Tiers**: Critical|High|Normal|Reference for selective knowledge preservation
- **Decision Rationale Store**: Persistent storage of WHY decisions were made, not just WHAT
- **Causal Relationship Tracking**: Bug → Root Cause → Fix → Why chains
- **Architectural Invariants Store**: Constraints that must be maintained across sessions

#### Phase 2: Modifying Hook Systems (Claude Code Compliant)
- **Enhanced UserPromptSubmit Hook**: Importance-weighted retrieval + invariant injection + decision context
- **Enhanced PostToolUse Hook**: Decision capture on every operation + invariant violation detection + auto-ingestion
- **Enhanced PreCompact Hook**: Critical decision extraction + causal chain preservation
- **SessionEnd Hook Integration**: Atomic commit generation + graph building
- **Schema Compliance**: Respects Claude Code hook schema limitations per hook type

#### Phase 3: Building Query Language
- **Declarative Query DSL** (TOML-based): Semantic search + importance filtering + constraint filtering + graph traversal + time-based filtering
- **CAMQueryExecutor**: Multi-step query execution with result composition
- **CLI Commands**: `query-dsl`, `infer-query-dsl`, `execute-query`
- **Research Base**: LOTUS semantic queries + Elastic Query DSL patterns

#### Phase 4: Implementing CMR Concepts
- **Contextual Memory Reweaving (CMR)**: Preserve decision inflection points instead of linear summaries
- **InflectionPointDetector**: Identifies WHERE reasoning changed direction
- **CMRPrimer Storage & Reconstruction**: 4-hour TTL primers for post-compact recovery
- **Token-Efficient Compression**: ~300 tokens to preserve critical decisions
- **Research Base**: CMR latent state reconstruction paper + recurrent context compression

### Added - SessionEnd Hook with Conventional Commits Integration

New hook: `session-end-with-commits.sh` (11-phase atomic pipeline)

- **Phase 1-2**: Gather session intelligence + determine commit type from operation keywords
- **Phase 3-4**: Infer scope from files + extract description from CAM decisions
- **Phase 5-6**: Build commit message (subject + body + footers) + validate Conventional Commits format
- **Phase 7-11**: Execute commit + build knowledge graph + store summary + cleanup + return status
- **Type Inference**: feat|fix|refactor|perf|test|style|chore from operation analysis
- **Scope Inference**: cam|hooks|cli|data-model|query-dsl|cmr from file patterns
- **Session Metadata**: Session-ID, date, operation counts, co-author in commit footers

### Added - GitHub Spec Commit Documentation

Comprehensive Conventional Commits 1.0.0 specification:

- **8 Commit Types**: feat (MINOR), fix (PATCH), breaking (MAJOR), chore|ci|docs|style|refactor|perf|test (NONE)
- **Scope Categories**: cam, hooks, cli, data-model, query-dsl, cmr, docs, git
- **Auto-Generation Algorithm**: Implemented in SessionEnd hook
- **Type + Scope Inference Rules**: Keyword-based type detection, file-pattern-based scope detection
- **Commit Examples**: Breaking changes, bug fixes, feature additions, documentation updates

### Files Added

**Phase 10 Architecture Plans** (Design Phase):
- `.claude/Plan #10 Phase 1 - Extending CAM's Data Model.md` (850+ lines, schema design + implementation)
- `.claude/Plan #10 Phase 2 - Modifying Hook Systems.md` (800+ lines, hook pipeline + code examples)
- `.claude/Plan #10 Phase 3 - Building Query Language.md` (650+ lines, DSL spec + executor + examples)
- `.claude/Plan #10 Phase 4 - Implementing CMR Concepts.md` (700+ lines, CMR architecture + compression)
- `.claude/Github Spec Commit.md` (600+ lines, commit standard + validation + examples)
- `.claude/cam-template/hooks/session-end-with-commits.sh` (400+ lines, 11-phase atomic commit pipeline)

**Phase 1 Implementation** (In Progress):
- `.claude/Phase 1 Implementation Strategy.md` (300+ lines, architecture + migration plan)
- `.claude/cam-template/migrations/v1.8_phase_1_data_model.py` (400+ lines, schema migration script)
- `.claude/cam-template/phase_1_methods.py` (600+ lines, 16 CAM class methods)
- `.claude/Phase 1 Implementation Summary.md` (250+ lines, integration checklist + next steps)

### Implementation Status

**Phase 1 - Extending CAM's Data Model**:
- ✅ Architecture designed and documented
- ✅ Migration script created (ready to execute)
- ✅ 16 CAM class methods implemented
- ✅ Integration plan and checklist created
- 🔄 Awaiting integration into cam_core.py (3-4 days work)

---

## [1.7.1] - 2025-12-08

### Fixed

- **Stop Hook Schema Validation Error** (`suggest-compact.sh`)
  - Stop hooks do NOT support `hookSpecificOutput.additionalContext`
  - Only PreToolUse, UserPromptSubmit, PostToolUse support that schema
  - Changed to print suggestions to stderr (visible in `--verbose` mode)
  - Returns simple `{"continue": true}` response

- **PreCompact Hook jq --argjson Error** (`crystallize.sh`)
  - Added numeric validation before jq `--argjson` calls
  - Prevents "invalid JSON text passed to --argjson" when variables are empty
  - Variables validated: `EDIT_COUNT`, `WRITE_COUNT`, `BASH_COUNT`, `READ_COUNT`, `TRANSCRIPT_LINES`
  - Regex validation ensures all values are valid integers before JSON generation

### Changed

- **CHANGELOG.md Location**
  - Moved from `release/cam-template/CHANGELOG.md` to repository root
  - Now accessible at `/CHANGELOG.md` for better visibility

---

## [1.7.0] - 2025-12-08

### Added - Phase 6: Automatic Context Crystallization

Seamless session knowledge preservation before context compaction with automatic post-compact recovery.

- **PreCompact Hook** (`crystallize.sh`)
  - Fires before any compaction (manual `/compact` or auto-compact)
  - Analyzes operations log, git state, and transcript
  - Generates structured summary with trigger type (manual/auto)
  - Stores to CAM with primer tags (`session-primer`, `pre-compact`, `continuity`)
  - Caches primer file for post-compact recovery
  - Reads project path from session state (PreCompact doesn't receive `cwd`)

- **Stop Hook** (`suggest-compact.sh`)
  - Proactively suggests `/compact` when context grows large
  - Warning threshold: 800 transcript lines
  - Urgent threshold: 1200 transcript lines
  - 15-minute cooldown between suggestions
  - Checks `stop_hook_active` to prevent infinite loops

- **Session State System** (cross-hook communication)
  - Written by SessionStart (which has `cwd`)
  - Read by PreCompact/Stop (which don't have `cwd`)
  - Directory: `~/.claude/.session-state/`
  - 24-hour expiry, cleaned on SessionEnd

- **Primer System** (JSON-based post-compact recovery)
  - Auto-injection on first message after compact
  - 4-hour expiry
  - Per-project isolation
  - Directory: `~/.claude/.session-primers/`

- **New CLI Command**
  - `primer-status` - Show active session primers and their status

### Changed

- **prompt-cam.sh** - Now detects and injects primers before CAM query
- **session-start.sh** - Writes session state + cleans expired primers
- **session-end.sh** - Cleans up session state file
- **settings-hooks.json** - Added PreCompact (60s timeout), Stop (10s timeout)

### Technical

- PreCompact/Stop hooks verified: Do NOT receive `cwd` field
- PreCompact receives: `session_id`, `transcript_path`, `trigger`, `custom_instructions`
- Stop receives: `session_id`, `transcript_path`, `stop_hook_active`
- Session state bridges tool-level hooks (have cwd) to session-level hooks (no cwd)
- Primer lifecycle: Create on PreCompact → Consume on UserPromptSubmit → Expire after 4h

### Data Flow

```
SessionStart (has cwd) ──writes──> ~/.claude/.session-state/{id}.json
                                            │
PreCompact (no cwd) ────reads───────────────┘
         │
         └──writes──> ~/.claude/.session-primers/{project}.primer
                                            │
UserPromptSubmit ───────reads & deletes─────┘
         │
         └──injects──> [SESSION PRIMER] context into response
```

---

## [1.6.0] - 2025-12-08

### Added - Ralph Wiggum Integration

CAM now supports the Ralph Wiggum iterative development technique with persistent memory across loops.

- **Ralph Data Types**
  - `ralph_iteration` - Individual iteration summaries
  - `ralph_loop_summary` - Complete loop outcomes
  - `ralph_prompt_pattern` - Effective prompt patterns (future use)

- **New Methods** (cam_core.py)
  - `get_ralph_loops(limit, outcome)` - Retrieve recent Ralph loop summaries
  - `get_ralph_iterations(loop_id)` - Get all iterations for a specific loop
  - `query_ralph_patterns(task_description)` - Semantic search for similar past loops
  - `store_ralph_iteration(...)` - Store iteration summary (used by hooks)
  - `store_ralph_loop_summary(...)` - Store complete loop outcome (used by hooks)

- **New CLI Commands**
  - `ralph-loops [--limit N] [--outcome TYPE] [--successful]` - List recent Ralph loops
  - `ralph-history <loop_id>` - View iterations for a specific loop
  - `ralph-patterns "task description"` - Find patterns from similar tasks
  - `store-ralph-iteration <loop_id> <iteration> <outcome> <project> [changes]` - Store iteration (hook use)
  - `store-ralph-loop <json_data>` - Store loop summary (hook use)

### Purpose

Enables **Learning Loops** - Ralph iterations that leverage historical patterns:
- Loop Start: Query CAM for patterns from similar past tasks
- Each Iteration: Optionally store iteration summary for analytics
- Loop End: Store comprehensive outcome for future reference
- Cross-Loop: Future loops benefit from past successes and failures

### Integration

Ralph Wiggum plugin modifications required (see README.md for instructions):
- `setup-ralph-loop.sh` - Add CAM query at loop start
- `stop-hook.sh` - Add CAM storage at iteration/completion

### Architecture

CAM provides the memory layer; Ralph provides the execution pattern:
- CAM can be used without Ralph (standalone memory system)
- Ralph can be used without CAM (falls back gracefully)
- Combined: Intelligent persistence across iterative loops

---

## [1.5.2] - 2025-12-08

### Added - Phase 6: Session Memory System

- **Session Retrieval Commands**
  - `sessions [--limit N]` - List recent sessions with metadata
  - `last-session` - Get the most recent session summary
  - `session <id>` - Get specific session details by ID (supports partial matching)
  - `store-session <id> <json>` - Store structured session summary (used by hooks)

- **Metadata Type Filtering**
  - `query <text> --type TYPE` - Filter semantic search by metadata type
  - Supports: `session_summary`, `ephemeral_note`, `operation`, etc.
  - New method: `query_by_metadata_type()` for programmatic access

- **Session Memory Methods** (cam_core.py)
  - `get_sessions(limit)` - Retrieve list of recent sessions
  - `get_session_summary(session_id)` - Get detailed session summary
  - `get_last_session()` - Get most recent session
  - `store_session_summary(...)` - Store structured session with metadata
  - `query_by_metadata_type(query, type, top_k)` - Type-filtered semantic search

### Changed

- **SessionEnd Hook** - Complete rewrite for intelligent summaries
  - Now aggregates operations from database (not just counting log lines)
  - Extracts files modified from Edit/Write operations
  - Creates structured session summaries with `type: "session_summary"`
  - Summaries include: operation counts by type, files modified list, timestamps
  - Stored via new `store-session` command for proper metadata

- **Query Command**
  - Added `--type TYPE` flag for metadata type filtering
  - Enables queries like: `cam.sh query "session" --type session_summary`

### Technical

- Session summaries stored with metadata type `session_summary` (not `ephemeral_note`)
- Enables reliable retrieval via `get_sessions()` and `last-session` commands
- Backward compatible: existing annotations still retrievable
- Session data extracted via SQL queries on annotations table

### Purpose

Solves the "what happened last session" problem:
- Before: Claude had to run multiple semantic queries returning noise
- After: `cam.sh last-session` returns structured summary instantly

---

## [1.5.1] - 2025-12-08

### Fixed

- **Source Type Schema Mismatch** - Critical bug fix
  - Database CHECK constraint only allowed: `code`, `docs`, `operation`, `external`, `conversation`
  - But code auto-detected and advertised `config` as valid type
  - Fix: Added `VALID_DB_SOURCE_TYPES` and `SOURCE_TYPE_MAPPING` constants
  - `store_embedding()` now normalizes `config` -> `code` before INSERT
  - Unknown types fallback to `code` to prevent constraint violations
  - Logs type normalization for debugging: `"Normalized source_type: config -> code"`

### Technical

- Added constants at module level:
  - `VALID_DB_SOURCE_TYPES = {'code', 'docs', 'operation', 'external', 'conversation'}`
  - `SOURCE_TYPE_MAPPING = {'config': 'code'}`
- Modified `store_embedding()` method to validate and map source types
- Backward compatible: existing databases unaffected, no migration needed

---

## [1.5.0] - 2025-12-07

### Added - Phase 5: Smart Auto-Ingest System

- **File Index Database** (`file_index.db`)
  - Tracks all ingested files with content hash, timestamp, and embedding ID
  - Enables smart change detection: only re-ingest if file content actually changed
  - New table: `file_index (file_path, content_hash, file_size, last_ingested_at, embedding_id, source_type)`

- **Directory Ingestion Support**
  - `ingest` command now accepts directories, not just files
  - Recursively scans and ingests all eligible files
  - Auto-detects source type (code, docs, config) based on file extension
  - Respects ignore patterns (node_modules, .git, lock files, etc.)

- **New CLI Commands**
  - `scan <directory> [type]` - Scan and report file status (new/modified/unchanged)
  - `check-file <path>` - Check single file status with details
  - `file-stats` - Show file index statistics (counts by type, total size)

- **Smart Ingest Flags**
  - `--force` - Re-ingest even if file is unchanged
  - `--dry-run` - Preview what would be ingested without doing it

- **PostToolUse Auto-Ingest** (Automatic)
  - When you Edit/Write a file, CAM automatically ingests the new content
  - Smart change detection: Only re-ingests if file content actually changed
  - Supports code (.py, .js, .ts, etc.), docs (.md), and config (.json, .yaml) files
  - Skips large files (>100KB), lock files, and ignored paths
  - Keeps CAM's semantic index synchronized with codebase changes

### Changed

- **`ingest` Command** - Complete rewrite
  - Now supports both files and directories
  - Auto-detects source type if not specified
  - Updates file index after ingestion
  - Cross-reference detection runs automatically for markdown files

- **PostToolUse Hook** (`update-cam.sh`)
  - Added Phase 5 auto-ingest for Edit/Write operations
  - Reports auto-ingested files in hook output
  - v1.4.0 → v1.5.0

- **Default Patterns**
  - Code: `.py, .js, .ts, .tsx, .jsx, .go, .rs, .java, .c, .cpp, .h, .rb, .php, .swift, .kt, .scala, .sh`
  - Docs: `.md, .mdx, .rst, .txt, .ai/**/*`
  - Config: `.json, .yaml, .yml, .toml, .ini, .cfg, Dockerfile, Makefile`
  - Ignored: `node_modules, venv, .git, dist, build, lock files, binaries, media`

### Technical

- `cam_core.py` - Added FileIndexEntry dataclass, file index methods, scan/check-file/file-stats commands
- Added `_detect_cross_refs()` helper function for markdown cross-reference detection
- Configuration constants: `DEFAULT_INGEST_PATTERNS`, `DEFAULT_IGNORE_PATTERNS`, `MAX_INGEST_FILE_SIZE`
- New database: `file_index.db` created automatically on CAM initialization

### Documentation

- Updated `global-claude.md` with new ingestion commands and auto-ingest documentation
- Updated `scaffold-ai.sh` templates (CLAUDE.md, GEMINI.md, cursor-rules.mdc)
- All agent instruction files now document directory ingestion and scan commands

---

## [1.4.1] - 2025-12-05

### Fixed
- **`__HOME__` Placeholder Substitution Bug** (`cam-sync-template.sh`)
  - Hook paths in `settings.json` were broken due to `__HOME__` placeholders not being replaced
  - Root cause: `deploy_settings()` merged `settings-hooks.json` but never substituted `__HOME__` with `$HOME`
  - Error message: `Failed with non-blocking status code: /bin/sh: __HOME__/.claude/hooks/session-start.sh: No such file or directory`
  - **Fix**: Added `sed` substitution step after both fresh copy and jq merge operations
  - Cross-platform compatible (macOS `sed -i ''` vs Linux `sed -i`)

### Changed
- **`settings-hooks.json`** - Updated comment to document automatic `__HOME__` substitution behavior
- **`cam-sync-template.sh`** - Now properly expands `__HOME__` to `$HOME` in deployed settings

### For Users
- If you have broken hooks, run: `~/.claude/cam-template/hooks/cam-sync-template.sh`
- Or manually fix: `sed -i '' "s|__HOME__|$HOME|g" ~/.claude/settings.json`

---

## [1.4.0] - 2025-12-04

### Added
- **Automatic Relationship System** (Phase 1-4 Implementation)
  - Graph building bootstraps relationships from existing embeddings via `graph build`
  - SessionEnd hook now automatically builds knowledge graph at session close
  - PostToolUse hook creates "modifies" relationships when editing .ai/ documents
  - Ingest command detects markdown cross-references and creates "references" relationships

- **New CLI Commands**
  - `relate <source> <target> <type> [weight]` - Create manual relationships between embeddings
  - `find-doc <file_path>` - Look up embedding ID by source file path

- **Relationship Types**
  - `temporal` - Time-based sequence patterns (auto-discovered)
  - `semantic` - Content similarity > 0.65 threshold (auto-discovered)
  - `causal` - Combined temporal + semantic inference (auto-discovered)
  - `modifies` - Operation → Document relationship (PostToolUse hook)
  - `references` - Document → Document cross-reference (ingest-time detection)

### Changed
- **SessionEnd Hook** (`session-end.sh`)
  - Added automatic graph building after session operations
  - Graph stats included in session summary output
  - 60-second timeout prevents blocking on large databases

- **PostToolUse Hook** (`update-cam.sh`)
  - Now synchronous (was async) to capture embedding ID for relationships
  - Creates "modifies" relationships for .ai/ document edits
  - Enhanced context output includes relationship creation info

- **cam-note.sh**
  - Now outputs actual embedding ID for relationship tracking
  - ID format: `[v] Stored ephemeral note: <title> (ID: <actual_id>)`

### Technical
- `cam_core.py` - Added relate, find-doc CLI commands
- `cam.sh` - Added relate, find-doc to passthrough commands
- Ingest command now parses markdown for `[text](path.md)` links
- Cross-references created with weight 0.8 and metadata

---

## [1.3.0] - 2025-12-04

### Added
- **`get` Command** (`cam.sh get <id>`)
  - New command to retrieve full embedding content by ID
  - Returns complete content, metadata, source type, source file, and creation timestamp
  - Useful for inspecting CAM entries after semantic search
  - Added `get_embedding()` method to CAM class in `cam_core.py`

- **Automatic Dependency Check** (`check_dependencies()` in `cam.sh`)
  - Automatically detects missing Python dependencies (e.g., `google-generativeai`)
  - Auto-installs from `requirements.txt` when dependencies are missing
  - Runs before Python commands (query, get, stats, etc.)
  - Graceful error handling with manual installation instructions

### Fixed
- **SessionStart Hook Schema Compliance**
  - Added missing `hookEventName: "SessionStart"` to JSON output
  - Both CAM-initialized and CAM-not-initialized paths now include `hookEventName`
  - Resolves: "JSON validation failed: Invalid input" errors on session start

### Changed
- **Unicode Removal** (ASCII-only output)
  - Replaced Unicode box-drawing characters with ASCII equivalents
  - All output now uses standard ASCII for maximum terminal compatibility

---

## [1.2.9] - 2025-12-03

### Added
- **Smart Decision-Point CAM Integration**
  - Intelligent query filtering: CAM queries only at high-value decisions (Edit/Write operations, architectural Bash commands)
  - 30-minute result caching: Eliminates redundant queries and latency accumulation
  - SessionStart context injection: Loads recent work patterns on session startup
  - New cache management script: `cam-cache-clean.sh` for lifecycle management

### Changed
- **Hook Schema Compliance**
  - All hooks now fully compliant with Claude Code hook JSON schema
  - Improved JSON escaping for robust handling of special characters
  - Optimized matcher patterns: Specific tools (Bash|Read|Edit|Write) instead of wildcards
  - Better result extraction: Complete first CAM result instead of line-based truncation

- **Documentation Enhancement**
  - Added "Smart CAM Triggering" section to CLAUDE.md with performance expectations
  - Added cache management instructions to CLAUDE.md
  - Added "Latest Updates" section to README.md explaining new features
  - Documented "Proactive CAM Usage" patterns for manual consultation

### Fixed
- **CAM Result Truncation**: SessionStart and PreToolUse hooks were truncating results with `head` command; now extract complete results
- **JSON Escaping**: CAM metadata now properly escaped to prevent annotation crashes
- **Result Extraction**: Replaced line-based extraction with logical result extraction using AWK

### Performance
- Session startup: +1-2 seconds (one-time, acceptable)
- First decision point: ~500ms CAM query
- Subsequent identical patterns: ~0ms (cached)
- Total context bloat: ~15-20 tokens per session (negligible)
- Multiple edits: First triggers CAM, subsequent use cache (instant)

### Backward Compatibility
✅ All changes backward compatible
✅ Existing CAM databases work unchanged
✅ Existing configurations work unchanged
✅ No breaking changes to APIs or schemas

---

## [1.2.8] - 2025-11-26

### Changed
- **Public Release Preparation**
  - Complete refactoring of init-cam.sh with unified CAM + .ai/ scaffolding
  - Version comparison logic with upgrade prompts
  - Integration with scaffold-ai.sh for .ai/ documentation

- **Emoji Removal (ASCII Art Replacement)**
  - Replaced all emojis with ASCII symbols across all scripts and cam_core.py
  - Symbol mapping: [v]=success, [x]=error, [!]=warning, ==>=setup, -->=file, >>>=search
  - Additional symbols: [+]=install, [db]=database, [py]=python, [--]=skip, [#]=info, [*]=tip

- **Two Sources of Truth Semantics**
  - Updated all agent entry points (CLAUDE.md, GEMINI.md, cursor-rules.mdc)
  - Changed from "single source of truth" to "two sources of truth" (.ai/ + CAM)
  - Updated .ai/README.md, sync-guide.md, and maintaining-docs.md

### Added
- **init-cam.sh Complete Rewrite**
  - INTERFACE INITIALIZATION banner with press-any-key prompt
  - Version comparison between project and template
  - Graceful exit conditions with specific messages
  - NEXT STEPS section with guidance
  - CODEBASE ANALYSIS bootstrap prompts (parts 1 & 2)
  - Integration calls to scaffold-ai.sh

- **Release Directory Structure**
  - New `severance/release/` folder for public distribution
  - Contains cam-template/, global-claude.md, README.md

### Removed
- **CLAUDE.md Creation from init-cam.sh**
  - CLAUDE.md is now created by scaffold-ai.sh only
  - Prevents duplication between CAM init and .ai/ scaffolding

### Files Modified
- `~/.claude/cam-template/hooks/init-cam.sh` - Complete rewrite
- `~/.claude/cam-template/hooks/scaffold-ai.sh` - Two sources semantics + emoji removal
- `~/.claude/cam-template/cam.sh` - Emoji removal
- `~/.claude/cam-template/cam_core.py` - Emoji removal + version bump
- `~/.claude/cam-template/hooks/*.sh` - Emoji removal (all hooks)

---

## [1.2.7] - 2025-11-26

### Changed
- **cam-sync-template.sh Direction Inverted**
  - Previously: Synced FROM live locations TO template
  - Now: Deploys FROM template TO live locations
  - Template (`~/.claude/cam-template/`) is now the canonical source of truth
  - Script renamed conceptually from "sync to template" to "deploy from template"

- **Workflow Change**
  - Edit files directly in `~/.claude/cam-template/`
  - Run `cam-sync-template.sh` to deploy to `~/.claude/hooks/` and `settings.json`
  - Projects pull updates via `./cam.sh upgrade`

### Added
- **Version Management Instructions** (`~/.claude/CLAUDE.md`)
  - Added explicit instructions for incrementing VERSION.txt when modifying cam-template
  - References VERSIONING.md for semantic versioning rules
  - Documents the deploy workflow

### Files Modified
- `~/.claude/hooks/cam-sync-template.sh` - Complete rewrite with inverted direction
- `~/.claude/CLAUDE.md` - Added Version Management section
- `~/.claude/cam-template/VERSION.txt` - Bumped to 1.2.7
- `~/.claude/cam-template/cam_core.py` - Updated CAM_VERSION to 1.2.7

---

## [1.2.6] - 2025-11-26

### Added
- **Release Management Command** (`cam.sh release`)
  - New `./cam.sh release <version>` command automates version management
  - Updates VERSION.txt in template
  - Updates CAM_VERSION in cam_core.py
  - Scaffolds CHANGELOG.md entry with template sections
  - Shows next steps reminder
  - Validates semantic versioning format (x.y.z)

- **CAM Infrastructure Change Detection** (`update-cam.sh`)
  - PostToolUse hook now detects modifications to CAM infrastructure files
  - Shows reminder: "Remember to run './cam.sh release <version>'"
  - Detected files: cam_core.py, cam.sh, .claude/hooks/*, cam-template/*, CLAUDE.md

### Changed
- **VERSION file renamed to VERSION.txt**
  - All CAM version files renamed from `VERSION` to `VERSION.txt`
  - Updated references in: cam.sh, init-cam.sh, cam-sync-template.sh, migrate-to-template.sh
  - Applies to both template and project-level CAM instances

- **Hooks synchronized**
  - Added `cam-query-annotation.sh` to template (was missing from cam-template/hooks/)
  - Both ~/.claude/hooks/ and ~/.claude/cam-template/hooks/ now have identical 10 files

---


## [1.2.5] - 2025-11-25

### Fixed
- **Backup Cleanup After Upgrade** (`cam.sh`)
  - `.backup/` directory is now removed after successful upgrade
  - Previously, stale `.backup/` would persist indefinitely, blocking `cam-note.sh`
  - The v1.2.2 guard in `cam-note.sh` checks for `.backup/cam.sh` to prevent race conditions during upgrade
  - But if `.backup/` was never cleaned up, ALL PostToolUse annotations were silently blocked
  - **Impact**: CAM was not embedding operations since Nov 19 due to stale backup directory
  - **Fix**: `cam.sh upgrade` now runs `rm -rf "$BACKUP_DIR"` after successful installation test

### Changed
- `cam.sh` - Added backup cleanup step after successful upgrade (lines 177-181)
- Rollback message updated: "To rollback, run 'upgrade --force' with old template"

---

## [1.2.4] - 2025-11-24

### Added
- **Multi-Agent .ai Framework** (`scaffold-ai.sh`)
  - New scaffolding script creates `.ai/` documentation structure
  - Supports three AI agents: Claude Code, Gemini, Cursor
  - Creates entry points: `CLAUDE.md`, `GEMINI.md`, `.cursor/rules/cursor-rules.mdc`
  - All agents read from same `.ai/` source of truth
  - CAM integration documented for each agent (hooks for Claude, manual for Gemini/Cursor)
  - Includes "Codebase Analysis" bootstrap prompt for agent initialization

### Changed
- **scaffold-ai.sh Output**
  - Renamed "BOOTSTRAP PROMPT" section to "• CODEBASE ANALYSIS •"
  - Streamlined bootstrap prompt (removed redundant .ai/README.md reference)

### Files Added
- `~/.claude/hooks/scaffold-ai.sh` - Global scaffolding script
- `~/.claude/cam-template/hooks/scaffold-ai.sh` - Template version

---

## [1.2.3] - 2025-11-24

### Changed
- **PostToolUse Hook Annotation Scope** (`update-cam.sh`)
  - Expanded from "Edit, Write, Bash" to "Edit, Write, Bash, Read"
  - Removed "significant operations" filter - now captures all code changes
  - Rationale: Any code change can dramatically affect a project (no pre-filtering)
  - Let system learn naturally what matters through usage patterns and data
  - If annotation volume becomes problematic, adjustments will be made based on real data

### Improved
- `update-cam.sh` - Enhanced documentation explaining why all operations are captured

---

## [1.2.2] - 2025-11-21

### Fixed
- **PostToolUse Hook Race Condition** (`cam-note.sh`)
  - Added upgrade-detection guard to prevent cam-note.sh from executing cam.sh during upgrade operations
  - Skips annotation when `.backup/cam.sh` is present (indicates upgrade in progress)
  - Resolves: "eck: command not found" and syntax errors after `./cam.sh upgrade --force`
  - Mitigation: Prevents circular dependency where PostToolUse hook tries to annotate cam.sh modification while cam.sh is being replaced

### Changed
- `cam-note.sh` - Added upgrade-in-progress detection to skip annotation during upgrade window

---

## [1.2.1] - 2025-11-21

### Added
- **Force Upgrade Flag** (`--force` / `-f`)
  - `./cam.sh upgrade --force` - Reinstall even when versions match
  - Useful for recovering from partial upgrades or content drift
  - Shows tip about `--force` when versions already match

### Changed
- `cam.sh` - Added FORCE_UPGRADE flag handling in upgrade case
- `cam_core.py` - Version bump to 1.2.1

---

## [1.2.0] - 2025-11-21

### Added
- **Evaluation Framework** (Phase 1-3)
  - `eval embeddings` - STS correlation test (Pearson/Spearman)
  - `eval retrieval` - Precision/Recall/nDCG metrics
  - `eval graph` - Edge coherence, temporal consistency, node coverage
  - `eval extrinsic` - Operational utility analysis
  - `eval all` - Run all intrinsic evaluations
- **Benchmark Suite**
  - `benchmark dmr` - Deep Memory Retrieval (inspired by Zep, Jan 2025)
  - `benchmark locomo` - Long-Context Memory (inspired by A-Mem, Feb 2025)
  - `benchmark all` - Run all benchmarks
- **Graph CLI Commands**
  - `graph build` - Build knowledge graph from embeddings
  - `graph build --rebuild` - Clear and rebuild from scratch
  - `graph stats` - Show graph statistics
- **Rebuild Commands**
  - `rebuild graph` - Rebuild knowledge graph only
  - `rebuild embeddings` - Re-generate all embeddings
  - `rebuild all` - Full rebuild: embeddings + graph
- **CAMEvaluator Class** (~600 lines)
  - Research-based metrics from RAGAS, Zep, A-Mem, MTEB
  - Letter grade scoring (A+ to F)

### Changed
- `cam_core.py` - Now ~3300 lines (was ~1500)
- `cam.sh` - Added eval, benchmark, graph, rebuild command routing

---

## [1.1.0] - 2025-11-20

### Added
- **Graph Building Functions**
  - `cluster_embeddings_hierarchical()` - Hierarchical clustering with cosine distance
  - `extract_concept_name_from_cluster()` - Semantic concept naming
  - `create_graph_nodes()` - Node creation from clusters
  - `discover_temporal_relationships()` - Time-based edge discovery
  - `discover_semantic_relationships()` - Similarity-based edge discovery
  - `discover_causal_relationships()` - Combined temporal+semantic inference
  - `build_knowledge_graph()` - Unified pipeline
  - `normalize_edge_weights()` - Weight normalization per type

### Changed
- `cam_core.py` - Added graph building section (~500 lines)

---

## [1.0.0] - 2025-11-18

### Added
- **Core Infrastructure**
  - `cam_core.py` - Main library with CAM class
  - `cam.sh` - CLI wrapper with version management
  - `vectors.db` - SQLite for embeddings (768-dim Gemini)
  - `metadata.db` - SQLite for annotations
  - `graph.db` - SQLite for relationships
  - `operations.log` - Append-only event log

- **CAM Class Methods**
  - `embed()` - Generate embeddings via Gemini API
  - `store_embedding()` - Store content with vector
  - `annotate()` - Add metadata/tags to embeddings
  - `add_relationship()` - Create graph edges
  - `query()` - Semantic search with cosine similarity
  - `get_metadata()` - Retrieve annotations
  - `get_relationships()` - Query graph edges
  - `stats()` - Get CAM statistics

- **CLI Commands**
  - `version` - Show CAM version
  - `stats` - Show CAM statistics
  - `query <text> [top_k]` - Semantic search
  - `ingest <file> <type>` - Ingest file into CAM
  - `annotate <content>` - Add manual annotation
  - `upgrade` - Upgrade from template

- **Hook System** (in `~/.claude/hooks/`)
  - `session-start.sh` - SessionStart hook
  - `prompt-cam.sh` - UserPromptSubmit hook (query CAM before processing)
  - `query-cam.sh` - PreToolUse hook (query CAM before operations)
  - `update-cam.sh` - PostToolUse hook (annotate after operations)
  - `session-end.sh` - SessionEnd hook
  - `cam-note.sh` - Store ephemeral notes in CAM
  - `init-cam.sh` - Initialize CAM in new projects
  - `cam-sync-template.sh` - Sync changes to template

- **Protocol** (`CLAUDE.md`)
  - Hook architecture specification
  - CAM-First workflow documentation
  - 6W annotation schema
  - Cross-project knowledge graph design

---

## [0.0.0] - 2025-11-18

### Bootstrap
- Initial design conversation (`glass_box.md`)
- First embedding: glass_box.md (ID: 572ff1840d0f0a99)
- Philosophy: Black Box Revealer

---

## Upgrade Instructions

```bash
# Check current version
./cam.sh version

# Upgrade to latest
./cam.sh upgrade

# Force reinstall (even if versions match)
./cam.sh upgrade --force

# Or manually sync template
~/.claude/hooks/cam-sync-template.sh
```

---

## Version Compatibility

| Version | cam_core.py | cam.sh | hooks | CLAUDE.md |
|---------|-------------|--------|-------|-----------|
| 1.2.1   | ✓ | ✓ | ✓ | ✓ |
| 1.2.0   | ✓ | ✓ | ✓ | ✓ |
| 1.1.0   | ✓ | ✓ | ✓ | ✓ |
| 1.0.0   | ✓ | ✓ | ✓ | ✓ |

---

**Maintained by**: Claude Code + Human collaboration
**Template location**: `~/.claude/cam-template/`
