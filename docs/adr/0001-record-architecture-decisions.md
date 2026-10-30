# 0001: Record architecture decisions

- Status: accepted
- Date: 2026-10-30

## Context

Lucy is built by one developer with AI agents doing much of the typing. Decisions
made in a chat disappear unless they are written down where the next session
(human or agent) will read them.

## Decision

Every decision that shapes the public API, the file layout, the toolchain or a
cross-cutting behaviour gets an ADR in `docs/adr/`, numbered in order, using
`0000-template.md`. ADRs are not edited after acceptance except to mark them
superseded; a change of mind is a new ADR.

## Consequences

- `AGENTS.md` points agents at the ADRs before they change architecture.
- Reviewers can ask "which ADR covers this?" for any structural change.
