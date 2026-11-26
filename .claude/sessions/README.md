# Claude Code session log

`cba022af-e1b7-443d-acca-4c76441da202.jsonl` is the Claude Code chat that built this game, with images removed.

## Resume it on another machine

Claude Code looks for sessions in `~/.claude/projects/<project folder>/`. The folder name is the
project's full path with every character that is not a letter or digit replaced by `-`.
Examples: `C:\Users\me\dev\SwordSlots` becomes `C--Users-me-dev-SwordSlots`, and `/home/me/dev/SwordSlots` becomes `-home-me-dev-SwordSlots`.

From the repo root:

**Windows (PowerShell)**
```powershell
$dir = "$HOME\.claude\projects\" + ((Get-Location).Path -replace '[^A-Za-z0-9]', '-')
New-Item -ItemType Directory -Force $dir | Out-Null
Copy-Item .claude\sessions\*.jsonl $dir
claude --resume cba022af-e1b7-443d-acca-4c76441da202
```

**macOS / Linux**
```bash
dir="$HOME/.claude/projects/$(pwd | sed 's/[^A-Za-z0-9]/-/g')"
mkdir -p "$dir" && cp .claude/sessions/*.jsonl "$dir/"
claude --resume cba022af-e1b7-443d-acca-4c76441da202
```
