#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# scaffold-ai.sh - Auto-scaffold .ai/ documentation framework
# Version: 2.0.0
# ═══════════════════════════════════════════════════════════════════════════
#
# PURPOSE: Create standardized .ai/ documentation structure in any project
# USAGE:
#   ~/.claude/hooks/scaffold-ai.sh /path/to/project
#   ~/.claude/hooks/scaffold-ai.sh  # Uses current directory
#
# CREATES:
#   - .ai/ directory with full documentation structure
#   - CLAUDE.md (Claude Code entry point)
#   - GEMINI.md (Gemini entry point)
#   - .cursor/rules/cursor-rules.mdc (Cursor entry point)
#
# INTEGRATES WITH:
#   - init-cam.sh (CAM initialization)
#   - CAM hooks (automatic .ai/ indexing)
#
# ═══════════════════════════════════════════════════════════════════════════

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get project directory
PROJECT_DIR="${1:-$(pwd)}"
AI_DIR="$PROJECT_DIR/.ai"

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}    .ai Framework Scaffolding (Multi-Agent)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "Project: $PROJECT_DIR"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Check if .ai/ already exists
# ─────────────────────────────────────────────────────────────────────────────

if [ -d "$AI_DIR" ]; then
    echo -e "${YELLOW}[!] .ai/ directory already exists${NC}"
    echo -e "Location: $AI_DIR"
    echo ""
    read -p "Overwrite? This will REPLACE existing structure (y/N): " OVERWRITE
    if [[ ! $OVERWRITE =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}[v] Keeping existing .ai/ structure${NC}"
        exit 0
    fi
    echo -e "${YELLOW}Backing up existing .ai/ to .ai.backup/...${NC}"
    rm -rf "$PROJECT_DIR/.ai.backup"
    mv "$AI_DIR" "$PROJECT_DIR/.ai.backup"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Detect project type
# ─────────────────────────────────────────────────────────────────────────────

echo -e "${GREEN}>>> Detecting project type...${NC}"

PROJECT_TYPE="generic"
FRAMEWORK=""
LANGUAGE=""

# PHP/Laravel detection
if [ -f "$PROJECT_DIR/artisan" ]; then
    PROJECT_TYPE="laravel"
    FRAMEWORK="Laravel"
    LANGUAGE="PHP"
    echo -e "  Detected: ${GREEN}Laravel${NC}"
fi

# Node.js detection
if [ -f "$PROJECT_DIR/package.json" ]; then
    if [ "$PROJECT_TYPE" == "generic" ]; then
        PROJECT_TYPE="node"
        LANGUAGE="JavaScript/TypeScript"
    fi
    if grep -q '"next"' "$PROJECT_DIR/package.json" 2>/dev/null; then
        FRAMEWORK="Next.js"
        echo -e "  Detected: ${GREEN}Next.js${NC}"
    elif grep -q '"react"' "$PROJECT_DIR/package.json" 2>/dev/null; then
        FRAMEWORK="React"
        echo -e "  Detected: ${GREEN}React${NC}"
    elif grep -q '"vue"' "$PROJECT_DIR/package.json" 2>/dev/null; then
        FRAMEWORK="Vue"
        echo -e "  Detected: ${GREEN}Vue${NC}"
    fi
fi

# Python detection
if [ -f "$PROJECT_DIR/requirements.txt" ] || [ -f "$PROJECT_DIR/pyproject.toml" ]; then
    if [ "$PROJECT_TYPE" == "generic" ]; then
        PROJECT_TYPE="python"
        LANGUAGE="Python"
        echo -e "  Detected: ${GREEN}Python${NC}"
    fi
fi

# Go detection
if [ -f "$PROJECT_DIR/go.mod" ]; then
    PROJECT_TYPE="go"
    LANGUAGE="Go"
    echo -e "  Detected: ${GREEN}Go${NC}"
fi

# Rust detection
if [ -f "$PROJECT_DIR/Cargo.toml" ]; then
    PROJECT_TYPE="rust"
    LANGUAGE="Rust"
    echo -e "  Detected: ${GREEN}Rust${NC}"
fi

if [ "$PROJECT_TYPE" == "generic" ]; then
    echo -e "  Detected: ${YELLOW}Generic project${NC}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Create .ai/ directory structure
# ─────────────────────────────────────────────────────────────────────────────

echo -e "${GREEN}--> Creating .ai/ directory structure...${NC}"

mkdir -p "$AI_DIR"/{core,development,patterns,meta}

# ─────────────────────────────────────────────────────────────────────────────
# Create README.md (Navigation Hub)
# ─────────────────────────────────────────────────────────────────────────────

cat > "$AI_DIR/README.md" << 'AIREADME'
# AI Documentation

This directory contains all AI-related documentation for the project.

## Two Sources of Truth

1. **Hub**: This `.ai/` directory - Documentation structure
2. **CAM**: Semantic query/search database - Cross-session memory

## Quick Start

### For AI Tools

- **Claude Code**: Start with [CLAUDE.md](../CLAUDE.md) in the project root
- **Gemini**: Start with [GEMINI.md](../GEMINI.md) in the project root
- **Cursor**: Start with [.cursor/rules/cursor-rules.mdc](../.cursor/rules/cursor-rules.mdc)

All agents reference this `.ai/` directory for detailed documentation and CAM for semantic queries.

## Documentation Structure

```
.ai/
├── README.md                    # This file - Navigation hub
├── core/                        # Core project information
│   ├── technology-stack.md      # Version numbers
│   ├── project-overview.md
│   ├── application-architecture.md
│   └── deployment-architecture.md
├── development/                 # Development practices
│   ├── development-workflow.md
│   └── testing-patterns.md
├── patterns/                    # Code patterns
│   ├── database-patterns.md
│   ├── frontend-patterns.md
│   ├── security-patterns.md
│   └── api-and-routing.md
└── meta/                        # Documentation guides
    ├── maintaining-docs.md
    └── sync-guide.md
```

## Key Information

### Documentation Organization

All documentation lives here in the `.ai/` directory. Entry point files in the project root reference these files:
- `CLAUDE.md` - Claude Code entry point (has hook integration)
- `GEMINI.md` - Gemini entry point (manual CAM)
- `.cursor/rules/cursor-rules.mdc` - Cursor entry point (manual CAM)

### Version Numbers

**ONLY** stored in [core/technology-stack.md](core/technology-stack.md). Never duplicate elsewhere.

### Maintenance

See [meta/maintaining-docs.md](meta/maintaining-docs.md) for guidelines on updating documentation.

## Navigation

### Core Documentation
- [Technology Stack](core/technology-stack.md) - All versions and dependencies
- [Project Overview](core/project-overview.md) - Project description
- [Application Architecture](core/application-architecture.md) - System design
- [Deployment Architecture](core/deployment-architecture.md) - Deployment details

### Development
- [Development Workflow](development/development-workflow.md) - Setup and workflows
- [Testing Patterns](development/testing-patterns.md) - Testing strategies

### Patterns
- [Database Patterns](patterns/database-patterns.md) - Database implementation
- [Frontend Patterns](patterns/frontend-patterns.md) - Frontend development
- [Security Patterns](patterns/security-patterns.md) - Security guidelines
- [API & Routing](patterns/api-and-routing.md) - API design

### Meta
- [Maintaining Docs](meta/maintaining-docs.md) - Documentation maintenance
- [Sync Guide](meta/sync-guide.md) - Synchronization guidelines

---

**Remember**: Each piece of information exists in ONE location. Use cross-references, never duplicate. CAM provides semantic search across sessions.
AIREADME

echo -e "  [v] Created README.md"

# ─────────────────────────────────────────────────────────────────────────────
# Create core/ documents
# ─────────────────────────────────────────────────────────────────────────────

cat > "$AI_DIR/core/technology-stack.md" << EOF
# Technology Stack

**SINGLE SOURCE OF TRUTH** for all version numbers and dependencies.

## Overview

| Category | Technology | Version |
|----------|------------|---------|
| Language | ${LANGUAGE:-"TBD"} | TBD |
| Framework | ${FRAMEWORK:-"TBD"} | TBD |
| Database | TBD | TBD |
| Cache | TBD | TBD |

## Backend

<!-- Update with actual versions -->

## Frontend

<!-- Update with actual versions -->

## Development Tools

<!-- Update with actual versions -->

## Infrastructure

<!-- Update with actual versions -->

---

**Note**: All version references across documentation should link back to this file.
EOF

echo -e "  [v] Created core/technology-stack.md"

cat > "$AI_DIR/core/project-overview.md" << 'EOF'
# Project Overview

## What This Project Is

<!-- Describe what the project does -->

## Core Mission

<!-- One sentence mission statement -->

## Key Features

<!-- List main features -->

## Target Users

<!-- Who uses this -->

## Architecture Philosophy

<!-- High-level approach -->

---

See [application-architecture.md](application-architecture.md) for technical details.
EOF

echo -e "  [v] Created core/project-overview.md"

cat > "$AI_DIR/core/application-architecture.md" << 'EOF'
# Application Architecture

## System Overview

<!-- High-level architecture diagram or description -->

## Directory Structure

```
<!-- Project structure here -->
```

## Core Components

<!-- List and describe main components -->

## Data Models

<!-- Key models and relationships -->

## Service Layer

<!-- Business logic organization -->

---

See [technology-stack.md](technology-stack.md) for version details.
EOF

echo -e "  [v] Created core/application-architecture.md"

cat > "$AI_DIR/core/deployment-architecture.md" << 'EOF'
# Deployment Architecture

## Environments

| Environment | URL | Purpose |
|-------------|-----|---------|
| Development | localhost | Local development |
| Staging | TBD | Pre-production testing |
| Production | TBD | Live application |

## Infrastructure

<!-- Describe hosting, containers, etc. -->

## CI/CD Pipeline

<!-- Describe deployment process -->

## Configuration

<!-- Environment variables, secrets management -->

---

See [development-workflow.md](../development/development-workflow.md) for local setup.
EOF

echo -e "  [v] Created core/deployment-architecture.md"

# ─────────────────────────────────────────────────────────────────────────────
# Create development/ documents
# ─────────────────────────────────────────────────────────────────────────────

cat > "$AI_DIR/development/development-workflow.md" << 'EOF'
# Development Workflow

## Prerequisites

<!-- List required software -->

## Quick Start

```bash
# Clone repository
git clone <repo-url>
cd <project>

# Install dependencies
# <commands here>

# Start development server
# <commands here>
```

## Development Commands

| Command | Description |
|---------|-------------|
| TBD | TBD |

## Code Style

<!-- Formatting, linting rules -->

## Git Workflow

<!-- Branch naming, commit conventions -->

---

See [testing-patterns.md](testing-patterns.md) for testing instructions.
EOF

echo -e "  [v] Created development/development-workflow.md"

cat > "$AI_DIR/development/testing-patterns.md" << 'EOF'
# Testing Patterns

## Testing Strategy

<!-- Overview of testing approach -->

## Test Types

### Unit Tests

<!-- Unit testing patterns -->

### Integration Tests

<!-- Integration testing patterns -->

### E2E Tests

<!-- End-to-end testing patterns -->

## Running Tests

```bash
# Run all tests
# <command>

# Run specific tests
# <command>
```

## Test Coverage

<!-- Coverage requirements -->

---

See [development-workflow.md](development-workflow.md) for setup.
EOF

echo -e "  [v] Created development/testing-patterns.md"

# ─────────────────────────────────────────────────────────────────────────────
# Create patterns/ documents
# ─────────────────────────────────────────────────────────────────────────────

cat > "$AI_DIR/patterns/database-patterns.md" << 'EOF'
# Database Patterns

## Overview

<!-- Database technology and approach -->

## Models

<!-- Key models and their purpose -->

## Relationships

<!-- Model relationships -->

## Migrations

<!-- Migration patterns -->

## Query Patterns

<!-- Common query patterns -->

---

See [application-architecture.md](../core/application-architecture.md) for data model overview.
EOF

echo -e "  [v] Created patterns/database-patterns.md"

cat > "$AI_DIR/patterns/frontend-patterns.md" << 'EOF'
# Frontend Patterns

## Overview

<!-- Frontend technology and approach -->

## Component Structure

<!-- How components are organized -->

## State Management

<!-- State management approach -->

## Styling

<!-- CSS/styling approach -->

## Best Practices

<!-- Frontend best practices -->

---

See [technology-stack.md](../core/technology-stack.md) for versions.
EOF

echo -e "  [v] Created patterns/frontend-patterns.md"

cat > "$AI_DIR/patterns/security-patterns.md" << 'EOF'
# Security Patterns

## Authentication

<!-- How authentication works -->

## Authorization

<!-- Permission and access control -->

## Data Protection

<!-- Encryption, sanitization -->

## Security Headers

<!-- HTTP security headers -->

## Best Practices

<!-- Security best practices -->

---

See [api-and-routing.md](api-and-routing.md) for API security.
EOF

echo -e "  [v] Created patterns/security-patterns.md"

cat > "$AI_DIR/patterns/api-and-routing.md" << 'EOF'
# API and Routing Patterns

## Route Structure

<!-- How routes are organized -->

## API Design

<!-- RESTful conventions, versioning -->

## Request Handling

<!-- Validation, middleware -->

## Response Format

<!-- Standard response structure -->

## Error Handling

<!-- Error response patterns -->

---

See [security-patterns.md](security-patterns.md) for API security.
EOF

echo -e "  [v] Created patterns/api-and-routing.md"

# ─────────────────────────────────────────────────────────────────────────────
# Create meta/ documents (COMPREHENSIVE VERSION)
# ─────────────────────────────────────────────────────────────────────────────

cat > "$AI_DIR/meta/maintaining-docs.md" << 'EOF'
# Maintaining Documentation

Guidelines for creating and maintaining AI documentation to ensure consistency and effectiveness across all AI tools (Claude, Gemini, Cursor).

> **Note**: `CLAUDE.md` is in the repository root, not in the `.ai/` directory.
> **Note**: `GEMINI.md` is in the repository root, not in the `.ai/` directory.
> **Note**: `cursor-rules.mdc` is in the repository root under `.cursor/rules/`, not in the `.ai/` directory.

## Documentation Structure

All AI documentation lives in the `.ai/` directory with the following structure:

```
.ai/
├── README.md                    # Navigation hub
├── core/                        # Core project information
├── development/                 # Development practices
├── patterns/                    # Code patterns and best practices
└── meta/                        # Documentation maintenance guides
```

## Required File Structure

When creating new documentation files:

```markdown
# Title

Brief description of what this document covers.

## Section 1

- **Main Points in Bold**
  - Sub-points with details
  - Examples and explanations

## Section 2

### Subsection

Content with code examples:

```language
// [v] DO: Show good examples
const goodExample = true;

// [x] DON'T: Show anti-patterns
const badExample = false;
```

## File References

- Use relative paths: `See [technology-stack.md](../core/technology-stack.md)`
- For code references: `` `app/Models/Application.php` ``
- Keep links working across different tools

## Content Guidelines

### DO:
- Start with high-level overview
- Include specific, actionable requirements
- Show examples of correct implementation
- Reference existing code when possible
- Keep documentation DRY by cross-referencing
- Use bullet points for clarity
- Include both DO and DON'T examples

### DON'T:
- Create theoretical examples when real code exists
- Duplicate content across multiple files
- Use tool-specific formatting that won't work elsewhere
- Make assumptions about versions - specify exact versions

## Rule Improvement Triggers

Update documentation when you notice:
- New code patterns not covered by existing docs
- Repeated similar implementations across files
- Common error patterns that could be prevented
- New libraries or tools being used consistently
- Emerging best practices in the codebase

## Analysis Process

When updating documentation:
1. Compare new code with existing rules
2. Identify patterns that should be standardized
3. Look for references to external documentation
4. Check for consistent error handling patterns
5. Monitor test patterns and coverage

## Rule Updates

### Add New Documentation When:
- A new technology/pattern is used in 3+ files
- Common bugs could be prevented by documentation
- Code reviews repeatedly mention the same feedback
- New security or performance patterns emerge

### Modify Existing Documentation When:
- Better examples exist in the codebase
- Additional edge cases are discovered
- Related documentation has been updated
- Implementation details have changed

## Quality Checks

Before committing documentation changes:
- [ ] Documentation is actionable and specific
- [ ] Examples come from actual code
- [ ] References are up to date
- [ ] Patterns are consistently enforced
- [ ] Cross-references work correctly
- [ ] Version numbers are exact and current

## Continuous Improvement

- Monitor code review comments
- Track common development questions
- Update docs after major refactors
- Add links to relevant documentation
- Cross-reference related docs

## Deprecation

When patterns become outdated:
1. Mark outdated patterns as deprecated
2. Remove docs that no longer apply
3. Update references to deprecated patterns
4. Document migration paths for old patterns

## Synchronization

### Single Source of Truth
- Each piece of information should exist in exactly ONE location
- Other files should reference the source, not duplicate it
- Example: Version numbers live in `core/technology-stack.md`, other files reference it

### Cross-Tool Compatibility
- **CLAUDE.md**: Entry point for Claude Code (references `.ai/` files)
- **GEMINI.md**: Entry point for Gemini (references `.ai/` files)
- **.cursor/rules/cursor-rules.mdc**: Entry point for Cursor (references `.ai/` files)
- **All tools**: Should get same information from `.ai/` directory

### When to Update What

**Version Changes** (frameworks, languages, packages):
1. Update `core/technology-stack.md` (single source)
2. Verify all agent files reference it correctly
3. No other files should duplicate version numbers

**Workflow Changes** (commands, setup):
1. Update `development/development-workflow.md`
2. Verify all cross-references work

**Pattern Changes** (how to write code):
1. Update appropriate file in `patterns/`
2. Add/update examples from real codebase
3. Cross-reference from related docs

## Documentation Files

Keep documentation files only when explicitly needed. Don't create docs that merely describe obvious functionality - the code itself should be clear.

## Breaking Changes

When making breaking changes to documentation structure:
1. Update this maintaining-docs.md file
2. Update `.ai/README.md` navigation
3. Update CLAUDE.md references
4. Update GEMINI.md references
5. Update `.cursor/rules/cursor-rules.mdc`
6. Test all cross-references still work
7. Document the changes in sync-guide.md

---

See [sync-guide.md](sync-guide.md) for synchronization rules.
EOF

echo -e "  [v] Created meta/maintaining-docs.md"

cat > "$AI_DIR/meta/sync-guide.md" << 'EOF'
# Documentation Sync Guide

This document explains how AI instructions are organized and synchronized across different AI tools used with this project.

## Overview

This project maintains documentation with a **two sources of truth** approach:

1. **Hub**: `.ai/` directory - Documentation structure
2. **CAM**: Semantic query/search database - Cross-session memory

Entry point files route to these sources:
- **CLAUDE.md** - Claude Code entry (has hook integration for automatic CAM)
- **GEMINI.md** - Gemini entry (manual CAM commands)
- **.cursor/rules/cursor-rules.mdc** - Cursor entry (manual CAM commands)

All AI tools reference the same `.ai/` directory and CAM database to ensure consistency.

## Cross-References

All systems reference the `.ai/` directory as the source of truth:

- **CLAUDE.md** → references `.ai/` files for detailed documentation
- **GEMINI.md** → references `.ai/` files for detailed documentation
- **.cursor/rules/cursor-rules.mdc** → references `.ai/` files for detailed documentation
- **.ai/README.md** → provides navigation to all documentation

## Maintaining Consistency

### 1. Core Principles (MUST be consistent)

These are defined ONCE in `.ai/core/technology-stack.md`:
- Framework version
- Language version
- All package versions

Other critical patterns defined in `.ai/`:
- Testing execution rules
- Security patterns and authorization requirements
- Code style requirements

### 2. Where to Make Changes

**For version numbers** (frameworks, languages, packages):
1. Update `.ai/core/technology-stack.md` (single source of truth)
2. Never duplicate version numbers in other locations

**For workflow changes** (how to run commands, development setup):
1. Update `.ai/development/development-workflow.md`
2. Verify all agent entry points reference correctly

**For architectural patterns** (how code should be structured):
1. Update appropriate file in `.ai/core/`
2. Add cross-references from related docs

**For code patterns** (how to write code):
1. Update appropriate file in `.ai/patterns/`
2. Add examples from real codebase
3. Cross-reference from related docs

**For testing patterns**:
1. Update `.ai/development/testing-patterns.md`

### 3. Update Checklist

When making significant changes:

- [ ] Identify if change affects core principles
- [ ] Update primary location in `.ai/` directory
- [ ] Verify CLAUDE.md references are still accurate
- [ ] Verify GEMINI.md references are still accurate
- [ ] Verify `.cursor/rules/cursor-rules.mdc` references are still accurate
- [ ] Update cross-references in related `.ai/` files
- [ ] Verify all relative paths work correctly
- [ ] Test links in markdown files

### 4. Common Inconsistencies to Watch

- **Version numbers**: Should ONLY exist in `.ai/core/technology-stack.md`
- **Testing instructions**: Execution requirements must be consistent
- **File paths**: Ensure relative paths work from their location
- **Command syntax**: Commands must be accurate across all docs
- **Cross-references**: Links must point to current file locations

## File Organization

```
/
├── CLAUDE.md                          # Claude Code entry point
├── GEMINI.md                          # Gemini entry point
├── .cursor/
│   └── rules/
│       └── cursor-rules.mdc           # Cursor entry point
└── .ai/                               # SINGLE SOURCE OF TRUTH
    ├── README.md                       # Navigation hub
    ├── core/                           # Project information
    ├── development/                    # Development practices
    ├── patterns/                       # Code patterns
    └── meta/                          # Documentation guides
```

## CAM Integration

CAM (Continuous Architectural Memory) indexes `.ai/` for semantic queries:

### For Claude Code (automatic via hooks)
Hooks automatically query and update CAM.

### For Gemini & Cursor (manual commands)
```bash
# Query CAM
./.claude/cam/cam.sh query "your intent"

# Add a note
./.claude/cam/cam.sh note "Title" "Description"

# Re-index .ai/ documentation
./.claude/cam/cam.sh ingest ".ai/" docs
```

---

**Golden Rule**: Each piece of information exists in ONE location in `.ai/`. All agent entry points route to `.ai/` and CAM.
EOF

echo -e "  [v] Created meta/sync-guide.md"

# ─────────────────────────────────────────────────────────────────────────────
# Create CLAUDE.md in project root
# ─────────────────────────────────────────────────────────────────────────────

echo -e "${GREEN}--> Creating AI agent entry points...${NC}"

if [ -f "$PROJECT_DIR/CLAUDE.md" ]; then
    echo -e "${YELLOW}  CLAUDE.md exists, skipping (won't overwrite)${NC}"
else
cat > "$PROJECT_DIR/CLAUDE.md" << 'CLAUDEMD'
# Project Instructions

> **Maintaining Instructions**: When updating AI instructions, see [.ai/meta/sync-guide.md](.ai/meta/sync-guide.md) and [.ai/meta/maintaining-docs.md](.ai/meta/maintaining-docs.md) for guidelines.

## CAM Protocol

**Reference**: `~/.claude/CLAUDE.md`

CAM (Continuous Architectural Memory) protocol specification, hooks, and annotation schemas are defined globally. Claude Code has hook integration for automatic CAM queries and annotations.

## Project Documentation

**Hub**: `.ai/README.md`
**CAM**: Semantically query/search the CAM database, execute scripts in the `@~/.claude/hooks` directory.

All project-specific documentation is organized in the `.ai/` directory, as well as the CAM interface database. These are the **two sources of truth** for all documentation.

### Quick Routes

| Topic | Location |
|-------|----------|
| Architecture | `.ai/core/application-architecture.md` |
| Tech Stack | `.ai/core/technology-stack.md` |
| Development | `.ai/development/development-workflow.md` |
| Testing | `.ai/development/testing-patterns.md` |
| Patterns | `.ai/patterns/` |
| Security | `.ai/patterns/security-patterns.md` |

## CAM Integration

Claude Code has automatic hook integration:
- **Auto-ingest**: Files are automatically ingested when you Edit/Write them
- **Smart detection**: Only re-ingests if file content actually changed

Manual commands also available:

- **Query**: `./.claude/cam/cam.sh query "intent"`
- **Add note**: `./.claude/cam/cam.sh note "Title" "Content"`
- **Ingest**: `./.claude/cam/cam.sh ingest <path> [type]` (file or directory)
- **Scan**: `./.claude/cam/cam.sh scan <directory>` (check what needs updating)
- **Stats**: `./.claude/cam/cam.sh stats`

## Project Policies

### Documentation

- **Sources of truth**: `.ai/` directory + CAM database
- **Single location**: Each fact in ONE place
- **Cross-reference**: Never duplicate
- **Proactive updates**: Update `.ai/` when you notice gaps

## Other AI Agents

This project supports multiple AI agents:
- **Claude Code**: `CLAUDE.md` (this file, has hook integration)
- **Gemini**: `GEMINI.md` (manual CAM)
- **Cursor**: `.cursor/rules/cursor-rules.mdc` (manual CAM)

All agents read from the same `.ai/` and CAM sources of truth.

---

*Claude reads `.ai/` for context. CAM hooks provide automatic semantic queries.*
CLAUDEMD
echo -e "  [v] Created CLAUDE.md"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Create GEMINI.md in project root
# ─────────────────────────────────────────────────────────────────────────────

if [ -f "$PROJECT_DIR/GEMINI.md" ]; then
    echo -e "${YELLOW}  GEMINI.md exists, skipping (won't overwrite)${NC}"
else
cat > "$PROJECT_DIR/GEMINI.md" << 'GEMINIMD'
# Project Instructions

> **Maintaining Instructions**: When updating AI instructions, see [.ai/meta/sync-guide.md](.ai/meta/sync-guide.md) and [.ai/meta/maintaining-docs.md](.ai/meta/maintaining-docs.md) for guidelines.

## Project Documentation

**Hub**: `.ai/README.md`
**CAM**: Semantically query/search the CAM database, execute scripts in the `@~/.claude/hooks` directory.

All project-specific documentation is organized in the `.ai/` directory, as well as the CAM interface database. These are the **two sources of truth** for all documentation.

### Quick Routes

| Topic | Location |
|-------|----------|
| Architecture | `.ai/core/application-architecture.md` |
| Tech Stack | `.ai/core/technology-stack.md` |
| Development | `.ai/development/development-workflow.md` |
| Testing | `.ai/development/testing-patterns.md` |
| Patterns | `.ai/patterns/` |
| Security | `.ai/patterns/security-patterns.md` |

## CAM Integration (Continuous Architectural Memory)

CAM provides semantic memory across sessions. Gemini does not have hook access, so CAM commands must be run manually via terminal.

### CAM Commands

```bash
# Query CAM
./.claude/cam/cam.sh query "your intent"

# Add a note to CAM
./.claude/cam/cam.sh note "Title" "Content description"

# Ingest file or directory (v1.5.0)
./.claude/cam/cam.sh ingest .ai/ docs          # Documentation
./.claude/cam/cam.sh ingest src/ code          # Source code
./.claude/cam/cam.sh ingest . --dry-run        # Preview all files

# Scan for new/modified files
./.claude/cam/cam.sh scan .

# View CAM statistics
./.claude/cam/cam.sh stats
```

### When to Use CAM

- **Before starting work**: Query for relevant context
- **After significant changes**: Run `ingest` on modified files/directories
- **When patterns emerge**: Document learnings for future sessions

## Project Policies

### Documentation

- **Sources of truth**: `.ai/` directory + CAM database
- **Single location**: Each fact in ONE place
- **Cross-reference**: Never duplicate
- **Proactive updates**: Update `.ai/` when you notice gaps

### Creating Documentation

When creating new documentation:
1. **Always** create in `.ai/<category>/`
2. **Never** create docs outside `.ai/` (except CLAUDE.md, GEMINI.md, .cursor/rules/)
3. **Update** `.ai/README.md` navigation
4. **Cross-reference** related docs

### Version Numbers

All version numbers live **ONLY** in `.ai/core/technology-stack.md`. Reference, never duplicate.

## Other AI Agents

This project supports multiple AI agents:
- **Claude Code**: `CLAUDE.md` (has hook integration)
- **Gemini**: `GEMINI.md` (this file, manual CAM)
- **Cursor**: `.cursor/rules/cursor-rules.mdc` (manual CAM)

All agents read from the same `.ai/` and CAM sources of truth.

---

*Gemini reads `.ai/` for context. Run CAM commands manually for semantic queries.*
GEMINIMD
echo -e "  [v] Created GEMINI.md"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Create .cursor/rules/cursor-rules.mdc in project root
# ─────────────────────────────────────────────────────────────────────────────

mkdir -p "$PROJECT_DIR/.cursor/rules"

if [ -f "$PROJECT_DIR/.cursor/rules/cursor-rules.mdc" ]; then
    echo -e "${YELLOW}  cursor-rules.mdc exists, skipping (won't overwrite)${NC}"
else
cat > "$PROJECT_DIR/.cursor/rules/cursor-rules.mdc" << 'CURSORRULES'
# Project Instructions for Cursor

> **Maintaining Instructions**: When updating AI instructions, see [.ai/meta/sync-guide.md](.ai/meta/sync-guide.md) and [.ai/meta/maintaining-docs.md](.ai/meta/maintaining-docs.md) for guidelines.

## Project Documentation

**Hub**: `.ai/README.md`
**CAM**: Semantically query/search the CAM database, execute scripts in the `@~/.claude/hooks` directory.

All project-specific documentation is organized in the `.ai/` directory, as well as the CAM interface database. These are the **two sources of truth** for all documentation.

### Quick Routes

| Topic | Location |
|-------|----------|
| Architecture | `.ai/core/application-architecture.md` |
| Tech Stack | `.ai/core/technology-stack.md` |
| Development | `.ai/development/development-workflow.md` |
| Testing | `.ai/development/testing-patterns.md` |
| Patterns | `.ai/patterns/` |
| Security | `.ai/patterns/security-patterns.md` |

## CAM Integration (Continuous Architectural Memory)

CAM provides semantic memory across sessions. Cursor does not have hook access, so CAM commands must be run manually via terminal.

### CAM Commands

```bash
# Query CAM
./.claude/cam/cam.sh query "your intent"

# Add a note to CAM
./.claude/cam/cam.sh note "Title" "Content description"

# Ingest file or directory (v1.5.0)
./.claude/cam/cam.sh ingest .ai/ docs          # Documentation
./.claude/cam/cam.sh ingest src/ code          # Source code
./.claude/cam/cam.sh ingest . --dry-run        # Preview all files

# Scan for new/modified files
./.claude/cam/cam.sh scan .

# View CAM statistics
./.claude/cam/cam.sh stats
```

### When to Use CAM

- **Before starting work**: Query for relevant context
- **After significant changes**: Run `ingest` on modified files/directories
- **When patterns emerge**: Document learnings for future sessions

## Project Policies

### Documentation

- **Sources of truth**: `.ai/` directory + CAM database
- **Single location**: Each fact in ONE place
- **Cross-reference**: Never duplicate
- **Proactive updates**: Update `.ai/` when you notice gaps

### Creating Documentation

When creating new documentation:
1. **Always** create in `.ai/<category>/`
2. **Never** create docs outside `.ai/` (except CLAUDE.md, GEMINI.md, .cursor/rules/)
3. **Update** `.ai/README.md` navigation
4. **Cross-reference** related docs

### Version Numbers

All version numbers live **ONLY** in `.ai/core/technology-stack.md`. Reference, never duplicate.

## Other AI Agents

This project supports multiple AI agents:
- **Claude Code**: `CLAUDE.md` (has hook integration)
- **Gemini**: `GEMINI.md` (manual CAM)
- **Cursor**: `.cursor/rules/cursor-rules.mdc` (this file, manual CAM)

All agents read from the same `.ai/` and CAM sources of truth.

---

*Cursor reads `.ai/` for context. Run CAM commands manually for semantic queries.*
CURSORRULES
echo -e "  [v] Created .cursor/rules/cursor-rules.mdc"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Update .gitignore
# ─────────────────────────────────────────────────────────────────────────────

echo -e "${GREEN}[--] Checking .gitignore...${NC}"

if [ -f "$PROJECT_DIR/.gitignore" ]; then
    if ! grep -q ".ai/\*.tmp" "$PROJECT_DIR/.gitignore" 2>/dev/null; then
        echo "" >> "$PROJECT_DIR/.gitignore"
        echo "# .ai/ temporary files" >> "$PROJECT_DIR/.gitignore"
        echo ".ai/*.tmp" >> "$PROJECT_DIR/.gitignore"
        echo -e "  [v] Added .ai/ temp exclusion to .gitignore"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Check for CAM and offer to initialize
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo -e "${BLUE}==> CAM Integration${NC}"

if [ -d "$PROJECT_DIR/.claude/cam" ]; then
    echo -e "${GREEN}[v] CAM already initialized${NC}"

    echo ""
    read -p "Index .ai/ documentation into CAM? (Y/n): " INDEX_AI
    if [[ ! $INDEX_AI =~ ^[Nn]$ ]]; then
        echo -e "${GREEN}Indexing .ai/ documentation...${NC}"
        cd "$PROJECT_DIR"
        if [ -f ".claude/cam/cam.sh" ]; then
            source ~/.claude/hooks/.env 2>/dev/null || true
            ./.claude/cam/cam.sh ingest ".ai/" docs 2>/dev/null || echo -e "${YELLOW}  [!] Manual indexing may be needed${NC}"
            echo -e "${GREEN}[v] .ai/ indexed into CAM${NC}"
        fi
    fi
else
    echo -e "${YELLOW}CAM not initialized in this project${NC}"
    read -p "Initialize CAM now? (Y/n): " INIT_CAM
    if [[ ! $INIT_CAM =~ ^[Nn]$ ]]; then
        if [ -f ~/.claude/hooks/init-cam.sh ]; then
            ~/.claude/hooks/init-cam.sh "$PROJECT_DIR"
        else
            echo -e "${RED}init-cam.sh not found at ~/.claude/hooks/${NC}"
            echo -e "Run manually: ~/.claude/hooks/init-cam.sh $PROJECT_DIR"
        fi
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Check for existing documentation to consolidate
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo -e "${BLUE}[#] Documentation Audit${NC}"

NON_AI_DOCS=$(find "$PROJECT_DIR" -maxdepth 2 -name "*.md" -not -path "$PROJECT_DIR/.ai/*" -not -path "$PROJECT_DIR/.git/*" -not -path "$PROJECT_DIR/.cursor/*" -not -name "README.md" -not -name "CLAUDE.md" -not -name "GEMINI.md" -not -name "CHANGELOG.md" -not -name "LICENSE*" -not -name "CONTRIBUTING.md" 2>/dev/null | head -10)

if [ -n "$NON_AI_DOCS" ]; then
    echo -e "${YELLOW}Found documentation outside .ai/:${NC}"
    echo "$NON_AI_DOCS" | while read -r doc; do
        echo "  - $(basename "$doc")"
    done
    echo ""
    echo -e "${YELLOW}Consider consolidating these into .ai/${NC}"
    echo -e "See: .ai/meta/maintaining-docs.md"
fi

for legacy_dir in docs DOCS documentation wiki notes; do
    if [ -d "$PROJECT_DIR/$legacy_dir" ]; then
        echo -e "${YELLOW}[!] Found legacy docs folder: $legacy_dir/${NC}"
        echo -e "  Consider migrating to .ai/"
    fi
done

# scaffold-ai.sh complete - init-cam.sh handles final user messaging
