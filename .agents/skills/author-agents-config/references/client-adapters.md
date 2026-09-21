# Client adapters

Documentation checked: **2026-09-16**. These are documentation-backed starting
points, not observations of the user's installed clients. Recheck the relevant
sources when introducing a client, migrating a layout, or encountering an
unknown version/surface. Preserve working configuration when evidence is unclear.

Keep compatibility facts here, not duplicated throughout `SKILL.md` or every
repository's always-on instructions. Do not refresh dates or files on a no-op sync.

## Starting points

| Client/surface | Shared instructions | Canonical skill exposure |
| --- | --- | --- |
| Codex | Native `AGENTS.md`; inspect startup scope and overrides. | Native `.agents/skills/` discovery. |
| Claude Code | `CLAUDE.md` can import adjacent `AGENTS.md`. | Documented project location is `.claude/skills/`; per-skill directory symlinks are documented. |
| Cline | `AGENTS.md` is a documented rule source; verify it is enabled. | `.cline/skills/` is documented; do not infer `.agents/skills/` support from format compatibility alone. |
| GitHub Copilot | Depends on the exact IDE/feature. VS Code chat supports `AGENTS.md`; other surfaces differ. | Check the selected surface's skill documentation; do not assume instruction support proves skill support. |

Sources and qualifications follow. The design preference is native discovery,
then actual import, then supported projection, then managed generated content.
A textual request to read a file is not the same as any of those mechanisms.

## Codex

Use canonical `AGENTS.md` directly. The documented instruction chain is built at
startup from project root to working directory. `AGENTS.override.md` can replace
`AGENTS.md` at the same level, and a configured size limit applies. Inspect
existing overrides rather than declaring the visible root file authoritative
for the effective prompt without checking.

Codex documents repository skills under `.agents/skills/`. Do not add a second
skill location when the canonical location is already discovered. Test from both
the repository root and a relevant subdirectory when scoped instructions matter;
do not equate initial discovery with automatic loading on every later file edit.

Sources:
- [Codex instruction discovery](https://developers.openai.com/codex/agent-configuration/agents-md)
- [Codex skill discovery](https://developers.openai.com/codex/build-skills)

## Claude Code

Claude Code documents importing `AGENTS.md` from `CLAUDE.md` using `@AGENTS.md`.
Use the bundled adapter template next to the canonical source. Root import does
not itself import every descendant instruction file: expose scoped files through
appropriate scoped adapters where needed and test actual loading.

Project skills are documented under `.claude/skills/`. Per-skill symlinked
directories are supported in the documented project location. Keep authored
content in the target repository's established canonical source; project it only
when needed and portable for the intended environment. Do not generalize this
support to every plugin/packaging surface or every other client.

Preserve real Claude-only instructions. Inspect existing settings and trust or
import-consent behavior without weakening them. A valid import line is a static
check, not proof that the file entered a particular running session.

Sources:
- [Claude Code memory and AGENTS.md imports](https://code.claude.com/docs/en/memory)
- [Claude Code skill locations](https://code.claude.com/docs/en/skills)

## Cline

The Rules documentation lists `AGENTS.md` as a supported source and describes
rule toggles. Prefer verified native loading instead of another shared-policy
file. Root support alone does not establish nested scope semantics.

There is a documentation discrepancy: the Rules page describes `.clinerules/`,
while the Config page describes `.cline/rules/`. Retain existing `.clinerules`
unless migration is requested and the actual target client/version supports the
new layout. Do not create both locations as a speculative fallback.

The Config/Skills documentation provides `.cline/skills/` as a client location.
Confirm discovery in the installed surface before choosing a link or other
projection from the canonical source. Preserve the canonical tree and check
whether another compatible location already exposes the same skill.

Sources:
- [Cline Rules](https://docs.cline.bot/customization/cline-rules)
- [Cline Config](https://docs.cline.bot/getting-started/config)
- [Cline Skills](https://docs.cline.bot/customization/skills)

## GitHub Copilot

Treat "Copilot" as incomplete compatibility information: identify the IDE and
feature, such as VS Code chat, code review, GitHub.com chat, cloud agent, or CLI.
The official support matrix differs across these surfaces. VS Code documents
native `AGENTS.md` support and qualifies nested behavior as experimental.

Do not create `.github/copilot-instructions.md` automatically for a surface that
already consumes the canonical source. For a surface that requires it, verify the
available reference/import semantics; do not use Claude's `@` syntax as a generic
cross-client import. A plain link or reading instruction must be labelled a
behavioral fallback unless the specific implementation documents stronger behavior.

Source:
- [Copilot support by surface](https://docs.github.com/en/copilot/reference/custom-instructions-support)
- [VS Code custom instructions](https://code.visualstudio.com/docs/agent-customization/custom-instructions)

## Projections and generated copies

Confirm link support for the actual OS, checkout, sandbox, and client. Prefer
relative links when supported. Verify resource paths from the linked skill's
location, prevent loops and out-of-workspace targets, and avoid overwriting
existing directories. Do not assume a link to the whole skills root behaves like
a supported per-skill entry.

If no adequate indirection exists, generated content must have a concrete,
repeatable regeneration path and a check that detects source drift. Reuse existing
repository tooling first. Calling a language model again is not deterministic
regeneration. A "generated" comment without a generator/check is insufficient.

Map each source and scope explicitly. Preserve the intended meaning of relative
references at the destination and respect client context limits. Do not flatten
all nested policies into a global adapter. If the requested scope cannot safely
include the necessary generation/checking work, report that limitation instead
of creating an independently maintained copy.

## Format source

The Agent Skills specification requires `name` and `description`; this shelf also
uses version and dependency metadata for local lifecycle and routing checks.
Supporting `references/` and `assets/` remain portable, and tool-specific
pre-approval frontmatter is intentionally not required by the core package.

- [Agent Skills specification](https://agentskills.io/specification)
