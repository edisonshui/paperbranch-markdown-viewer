# Domain documentation

Paperbranch is a single-context repository.

## Before exploring or changing the project

Read:

1. `CONTEXT.md` for the product glossary and canonical terminology.
2. The relevant ADRs under `docs/adr/`.
3. The specification and ticket governing the current work.

If a domain document does not exist, proceed without creating an empty placeholder.

## Use the glossary vocabulary

Use terms exactly as defined in `CONTEXT.md` in:

- Ticket titles and descriptions
- Type and module names
- Tests
- User-facing behavior descriptions
- Architecture and review findings

Avoid synonyms that `CONTEXT.md` explicitly rejects.

If implementation needs a domain concept that the glossary does not define, determine whether the concept is unnecessary or whether `CONTEXT.md` needs a new term.

## Respect ADRs

Do not silently contradict an accepted ADR. If new evidence challenges an ADR, identify the conflict and propose replacing or superseding the decision before implementing the conflicting behavior.
