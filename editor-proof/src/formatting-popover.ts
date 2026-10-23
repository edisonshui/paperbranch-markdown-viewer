import { commandsCtx } from "@milkdown/kit/core";
import type { Ctx } from "@milkdown/kit/ctx";
import type { CmdKey } from "@milkdown/kit/core";
import { tooltipFactory, TooltipProvider } from "@milkdown/kit/plugin/tooltip";
import {
  emphasisSchema,
  inlineCodeSchema,
  linkSchema,
  strongSchema,
  toggleEmphasisCommand,
  toggleInlineCodeCommand,
  toggleLinkCommand,
  toggleStrongCommand,
} from "@milkdown/kit/preset/commonmark";
import { strikethroughSchema, toggleStrikethroughCommand } from "@milkdown/kit/preset/gfm";
import type { MarkType } from "@milkdown/kit/prose/model";
import { TextSelection, type EditorState, type Selection } from "@milkdown/kit/prose/state";
import type { EditorView } from "@milkdown/kit/prose/view";
// The design skill's icon files, drawn with currentColor so the active state can tint them.
import linkIcon from "../../.claude/skills/paperbranch-design/icons/link.svg?raw";
import codeIcon from "../../.claude/skills/paperbranch-design/icons/code.svg?raw";

// Ticket 36: selecting text shows a small popover that toggles link, bold, italic, strikethrough, and inline code.
// Milkdown's tooltip plugin positions it with floating-ui and already hides it for an empty selection,
// an unfocused editor, and a read-only view. A blocked document never creates an editor, so it never shows.
export const formattingPopover = tooltipFactory("FORMATTING_POPOVER");

type Format = { label: string; face: string; className: string; mark: (ctx: Ctx) => MarkType; run: (ctx: Ctx, view: EditorView) => void };

// Milkdown assigns a command's key only when the editor starts, so it is read at click time.
function toggle(command: { key: CmdKey<undefined> }) {
  return (ctx: Ctx) => { ctx.get(commandsCtx).call(command.key); };
}

/** True when every text node in the selection carries the mark. */
function covers(state: EditorState, type: MarkType): boolean {
  const { from, to, empty } = state.selection;
  if (empty) return false;
  let sawText = false;
  let covered = true;
  state.doc.nodesBetween(from, to, (node) => {
    if (!node.isText) return;
    sawText = true;
    if (!type.isInSet(node.marks)) covered = false;
  });
  return sawText && covered;
}

const formats: Format[] = [
  {
    label: "Link",
    face: linkIcon,
    className: "icon",
    mark: (ctx) => linkSchema.type(ctx),
    // Removes a link anywhere in the selection, or asks for a URL. Deliberately no link editor UI.
    run: (ctx, view) => {
      const { from, to } = view.state.selection;
      if (view.state.doc.rangeHasMark(from, to, linkSchema.type(ctx))) {
        ctx.get(commandsCtx).call(toggleLinkCommand.key);
        return;
      }
      const href = window.prompt("Link URL")?.trim();
      view.focus();
      if (href) ctx.get(commandsCtx).call(toggleLinkCommand.key, { href });
    },
  },
  { label: "Bold", face: "B", className: "bold", mark: (ctx) => strongSchema.type(ctx), run: toggle(toggleStrongCommand) },
  { label: "Italic", face: "I", className: "italic", mark: (ctx) => emphasisSchema.type(ctx), run: toggle(toggleEmphasisCommand) },
  { label: "Strikethrough", face: "S", className: "strike", mark: (ctx) => strikethroughSchema.type(ctx), run: toggle(toggleStrikethroughCommand) },
  { label: "Inline code", face: codeIcon, className: "icon", mark: (ctx) => inlineCodeSchema.type(ctx), run: toggle(toggleInlineCodeCommand) },
];

export function configureFormattingPopover(ctx: Ctx): void {
  let provider: TooltipProvider | undefined;
  // The selection Escape dismissed. The popover stays hidden until the selection changes.
  let dismissed: Selection | undefined;

  // The provider's own rule plus Escape's dismissal. Updates pass no previous state, so every update re-checks this
  // rule instead of relying on the provider skipping an unchanged state.
  const shouldShow = (view: EditorView): boolean => {
    const { selection, doc } = view.state;
    if (dismissed && !selection.eq(dismissed)) dismissed = undefined;
    if (dismissed || selection.empty || !view.hasFocus() || !view.editable) return false;
    return !(selection instanceof TextSelection) || doc.textBetween(selection.from, selection.to).length > 0;
  };

  ctx.set(formattingPopover.key, {
    view: (view) => {
      const content = document.createElement("div");
      content.id = "formatting-popover";
      content.setAttribute("role", "toolbar");
      content.setAttribute("aria-label", "Formatting");
      const buttons = formats.map((format) => {
        const button = document.createElement("button");
        button.type = "button";
        button.tabIndex = -1;
        button.className = format.className;
        button.setAttribute("aria-label", format.label);
        button.setAttribute("aria-pressed", "false");
        button.innerHTML = format.face;
        // Keeps focus and the selection in the editor, so the popover never blurs it.
        button.addEventListener("mousedown", (event) => event.preventDefault());
        button.addEventListener("click", () => {
          format.run(ctx, view);
          refresh(view.state);
        });
        content.append(button);
        return button;
      });
      const refresh = (state: EditorState) => {
        formats.forEach((format, index) => buttons[index].setAttribute("aria-pressed", String(covers(state, format.mark(ctx)))));
      };

      // Appended to the body and absolutely positioned, so showing it reflows nothing in the document.
      provider = new TooltipProvider({ content, debounce: 20, offset: 6, root: document.body, shouldShow });
      provider.update(view);
      refresh(view.state);
      return {
        update: (updated) => {
          provider?.update(updated);
          refresh(updated.state);
        },
        destroy: () => {
          provider?.destroy();
          provider = undefined;
          content.remove();
        },
      };
    },
    props: {
      // Escape hides the popover and still reaches the editor.
      handleKeyDown: (view, event) => {
        if (event.key === "Escape" && !view.state.selection.empty) {
          dismissed = view.state.selection;
          provider?.hide();
        }
        return false;
      },
      handleDOMEvents: {
        blur: () => {
          provider?.hide();
          return false;
        },
      },
    },
  });
}
