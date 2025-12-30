# ai-foo

Reusable Claude Code plugins for development workflows.

## Plugins

### df

Development workflow plugin providing a structured feature development cycle:

```
/df:research → /df:plan → [/df:iterate] → /df:implement → [/df:validate] → /df:commit
```

Commands in brackets `[]` are optional.

| Command         | Purpose                                                  |
| --------------- | -------------------------------------------------------- |
| `/df:research`  | Comprehensive codebase research with parallel sub-agents |
| `/df:plan`      | Create detailed implementation plans                     |
| `/df:iterate`   | Update existing plans based on feedback                  |
| `/df:implement` | Execute plans phase by phase with verification           |
| `/df:validate`  | Verify implementation against plan, identify issues      |
| `/df:commit`    | Commit changes in logical chunks (Conventional Commits)  |

### Installation

**Via Marketplace:**

```
/plugin marketplace add fokkoru/ai-foo
```

Then open `/plugin` menu and install `df` from `ai-foo` marketplace.

**From local clone:**

```bash
git clone https://github.com/fokkoru/ai-foo.git
claude --plugin-dir /path/to/ai-foo/plugins/df
```

See [plugins/df/README.md](plugins/df/README.md) for detailed usage.
