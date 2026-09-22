# Ikemen GO — Agent Briefing

## What This Is

Ikemen GO is an open-source fighting game engine written in Go. It's a rewrite of the original Ikemen engine and aims for backwards-compatibility with M.U.G.E.N 1.1 Beta while expanding its features. It supports M.U.G.E.N characters, stages, and screenpacks.

**Do not try to build this project.** It requires FFmpeg, libxmp, SDL2, Go 1.27+ with the `arenas` experiment, and GPU drivers. Building is handled by CI and platform-specific scripts. Just read and edit code.

## Architecture

There are two separate scripting systems that serve different purposes:

**Character states (CNS/ZSS bytecode):**
```
compiler.go + compiler_functions.go → bytecode.go → char.go (per-frame execution)
```
- `compiler.go` (`CharCompiler`) tokenizes and parses `.cns`/`.zss` state files into bytecode (`BytecodeExp`, `StateBlock`, `BytecodeFunction`).
- `compiler_functions.go` contains the `scFunc` implementations that parse individual state controllers.
- `bytecode.go` is the VM. It contains `BytecodeExp` (trigger evaluation), `StateController` implementations (one per sctrl), and `StateBlock` (control flow). All the `run`/`Run` methods live here.
- `char.go` (`Char`) drives the VM per-frame via `actionPrepare()` → `actionRun()` → `actionFinish()` → `update()` → `tick()`.

**UI / menus / screenpacks (Lua):**
```
script.go (Go API) ↔ external/script/*.lua
```
- `script.go` registers Go functions into a gopher-lua `LState` via `systemScriptInit`. It also handles INI→Lua and JSON→Lua conversion.
- The Lua scripts in `external/script/` call those functions to drive menus, character select, and screenpack behavior.

**Game loop:** `system.go` (`System`) orchestrates everything. `System.action()` calls `CharList.action()` which iterates all characters.

**Rollback netcode:** `state.go` (`GameState`) serializes the full game state (chars, projectiles, explods, PalFX). `state_clone.go` provides generic deep-copy helpers (`Copyable[T]`, `CopySlice`, `CopyMap`). `netplay.go` and `rollback.go` handle networking and prediction.

**Rendering:** `render.go` is the abstraction. `render_gl33.go`, `render_gles32.go`, `render_vk.go` are the backends. Fonts (`font.go` → `font_gl33.go` etc.) follow the same pattern.

## Where to Make Changes

| What you want to do | Start here |
|---|---|
| Add or fix a state controller (sctrl) | `compiler_functions.go` (parsing) + `bytecode.go` (execution) |
| Add or fix a trigger | `compiler.go` (parsing) + `bytecode.go` (execution) + `script.go` (Lua equivalent) |
| Change character physics/hitboxes/movement | `char.go` |
| Change animation | `anim.go`, `char.go` |
| Change stage rendering or camera | `stage.go`, `camera.go`, `bgdef.go` |
| Change the fight screen layout/logic | `fightscreen.go` |
| Change the menu / screenpack system | `motif.go` + `external/script/*.lua` |
| Change the Lua API exposed to screenpacks | `script.go` |
| Change input handling | `input.go`, `input_sdl.go` |
| Change rendering (blending, shaders) | `render.go`, then the backend files |
| Change sound/music | `sound.go`, `music.go`, `audio_sdl.go` |
| Change video playback | `video_ffmpeg.go` |
| Change netplay / rollback | `netplay.go`, `rollback.go`, `state.go`, `state_clone.go` |
| Change config / options | `config.go`, `src/resources/defaultConfig.ini` |
| Change the default game logic (zss) | `data/*.zss` |

## Gotchas

- **Adding a sctrl or trigger requires two files.** Parsing goes in `compiler.go` or `compiler_functions.go`; execution goes in `bytecode.go`. Missing one side causes silent failures.
- **Trigger additions must also go in `script.go`.** Most triggers have a Lua counterpart registered via `luaRegister` (e.g. `StageVar` → `stageVar`) used by the debug display and Lua scripts. Keep both in sync.
- **`bytecode.go` is huge (~13k lines)** and contains both the VM core and every state controller implementation. Use `grep` to find the specific sctrl type you need.
- **Three render backends must stay in sync.** If you change `render.go`'s interface, update `render_gl33.go`, `render_gles32.go`, and `render_vk.go` (and their `font_*` counterparts).
- **`.zss` files in `data/` are the engine's own game logic**, written in the same CNS/ZSS language the engine compiles for user content. They're not Go code — they're compiled at load time.
- **`kfm.zss` and `kfm_big.zss` at the repo root** are test/preview files, not part of the engine.
- **`state.go` is rollback serialization**, not character state. The name is confusing — it's about saving/restoring game state for netplay prediction.
- **Keep state cloning simple.** `Clone` functions in `state_clone.go` should make full, faithful copies. Don't skip or special-case data based on how it happens to be used, since that breaks silently when the code changes. If a state is expensive to copy, make the data itself smaller where it's created instead.

## Working on Changes

- **Only make the requested change.** Don't rename, reword, restructure or "fix" nearby code on the side. Mention other findings instead, so the real change stays easy to review.
- **Ask when there's a design choice.** If there are several reasonable approaches, present them and let the maintainer pick rather than implementing one and revising it repeatedly.
- **Check why something exists before removing it.** Look at callers and threads first (e.g. mutexes, reset lines, grace periods). Code that looks redundant is often covering a less obvious path such as Turns preloading or character reloading.
- **Use `git --no-optional-locks` for read-only git commands** (`status`, `diff`). Tools that can't delete files may otherwise leave a stale `.git/index.lock` that blocks commits.

## Conventions

- **PR titles** use Conventional Commits: `<type>(<scope>): <summary>`
  - Types: `build`, `chore`, `docs`, `feat`, `fix`, `other`, `perf`, `refactor`, `style`, `test`
  - Scope is optional (e.g. `input`, `sctrl`, `trigger`)
  - Summary is imperative, lowercase, no trailing period
- **Code comments** in English. Explain intent, not just what the code does.
- **Keep comments short and to the point.** Plain language, 1–2 lines. State what the code prevents or why it's there (e.g. "Copy the sprite to prevent aliasing"), not a step-by-step story.
- **Don't remove or reword existing comments** unless the code they describe changed and they're no longer accurate.
- **PR and commit descriptions** follow the same rules as comments: short, plain, to the point.
- **PRs** need an associated issue. Major features need a discussion first.
- **Wiki docs** must be updated for new features (watch for the `docs-needed` label).

## Branching

- `develop` is the default branch. All new work goes here first.
- `release/X.Y` branches handle patch releases. Backport fixes with `git cherry-pick -x`.
- Tags: `vX.Y.0-rc.N` (RCs), `vX.Y.0` (stable), `vX.Y.N` (patches).

## Key Files

| File | What's there |
|---|---|
| `README.md` | Project overview, install, run instructions |
| `BUILDING.md` | Full build instructions (you won't need this — don't build) |
| `CONTRIBUTING.md` | PR process, code style, commit format |
| `go.mod` | Dependencies |

## Directory Map

| Path | What's in it |
|---|---|
| `src/` | All Go source (~50 files) |
| `src/resources/` | Default config/motif/storyboard INI files |
| `src/shaders/` | GLSL shaders + compiled `.spv` |
| `data/` | Default game logic (`.zss`, `.air`, `.cmd`, `.const`) |
| `external/script/` | Lua scripts for menus/screenpacks |
| `external/shaders/` | Post-processing shaders (HQ2x, HQ4x, Scanline) |
| `external/icons/` | App icons |
| `font/` | Default fonts and definitions |
| `build/` | Build scripts (don't run these) |
| `.github/` | CI workflows, issue templates |
