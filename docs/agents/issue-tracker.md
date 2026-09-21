# Issue tracker: local Markdown

Paperbranch tracks specifications and implementation tickets inside this repository.

## Locations

- Approved specifications live in `docs/specs/`.
- Each feature has a directory at `.scratch/<feature-slug>/`.
- Implementation tickets live at `.scratch/<feature-slug>/issues/<NN>-<slug>.md`.
- Ticket numbers follow dependency order, with blockers appearing first.
- Each ticket records its dependencies using a `**Blocked by:**` line.
- Each ticket records its state using a `**Status:**` line.

## Ticket lifecycle

- `ready-for-agent`: The ticket is defined and can begin when all blockers are resolved.
- `claimed`: An agent is currently implementing the ticket.
- `resolved`: Every acceptance criterion passes and the implementation has been verified.
- Before starting a ticket, confirm that every ticket named under `Blocked by` is `resolved`.
- When resolving a ticket, check its acceptance criteria and append the verification commands and commit hash under a `## Comments` heading.

## When a skill publishes a specification

Create or update the appropriate Markdown file under `docs/specs/`.

## When a skill publishes tickets

Create one file per ticket under `.scratch/<feature-slug>/issues/`. Never combine several implementation tickets into one file.

## When a skill fetches a ticket

Read the exact ticket path or ticket number supplied by the user.
