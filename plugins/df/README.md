# df

Development flow - workflow automation for individual developers.

## Overview

This plugin provides a structured workflow for feature development:

```
/df:research → /df:plan → [/df:iterate] → /df:implement → [/df:validate] → /df:commit
```

Note: Commands in brackets `[]` are optional.

## Commands

| Command         | Description                                                 |
| --------------- | ----------------------------------------------------------- |
| `/df:research`  | Comprehensive codebase research with parallel sub-agents    |
| `/df:plan`      | Create detailed implementation plans with thorough research |
| `/df:iterate`   | Update existing plans based on feedback                     |
| `/df:implement` | Execute plans with verification and phase-by-phase progress |
| `/df:validate`  | Verify implementation against plan, identify issues         |
| `/df:commit`    | Commit changes in logical chunks (Conventional Commits)     |

## Agents

| Agent                     | Description                               |
| ------------------------- | ----------------------------------------- |
| `codebase-locator`        | Find files by topic/feature               |
| `codebase-analyzer`       | Understand implementation details         |
| `codebase-pattern-finder` | Find similar patterns and examples        |
| `thoughts-locator`        | Discover documents in thoughts/ directory |
| `thoughts-analyzer`       | Extract insights from thought documents   |
| `web-search-researcher`   | Research modern web information           |

## Configuration

Create `.claude/df.local.md` in your project to customize paths:

```yaml
---
research_dir: thoughts/research
plans_dir: thoughts/plans
---
```

### Default Paths

If no configuration file exists:

- Research documents: `thoughts/research/`
- Implementation plans: `thoughts/plans/`

## Installation

### From GitHub

```bash
git clone https://github.com/fokkoru/ai-foo.git
claude --plugin-dir /path/to/ai-foo/plugins/df
```

### From Local Directory

```bash
claude --plugin-dir /path/to/df
```

### As Project-Local Commands

Copy commands directly into your project's `.claude/` directory:

```bash
cp -r df/commands your-project/.claude/commands/df
cp -r df/agents your-project/.claude/agents
```

Note: Project-local installation embeds the commands in your repository. Plugin installation keeps them external.

## Usage Examples

### Research the codebase

```
/df:research
> How does authentication work in this project?
```

### Create an implementation plan

```
/df:plan
> I need to add rate limiting to the API
```

### Execute a plan

```
/df:implement thoughts/plans/2024-01-15_rate-limiting.md
```

### Update an existing plan

```
/df:iterate thoughts/plans/2024-01-15_rate-limiting.md - add caching phase
```

### Validate implementation

```
/df:validate thoughts/plans/2024-01-15_rate-limiting.md
```

### Commit changes

```
/df:commit
```

## Workflow

1. **Research**: Understand the codebase and existing patterns
2. **Plan**: Create a detailed, phased implementation plan
3. **Iterate**: Adjust the plan based on findings
4. **Implement**: Execute the plan phase by phase with verification
5. **Validate**: Verify implementation against plan, identify issues
6. **Commit**: Create logical, well-organized commits
