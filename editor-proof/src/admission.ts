import { unified } from "unified";
import remarkParse from "remark-parse";
import remarkFrontmatter from "remark-frontmatter";
import remarkGfm from "remark-gfm";
import remarkMath from "remark-math";
import { visit } from "unist-util-visit";

export type BlockedReason = "front-matter" | "math";

export type AdmissionResult =
  | { status: "admitted" }
  | { status: "blocked"; reasons: BlockedReason[] };

// docs/adr/0004-block-unsafe-markdown-before-the-editor.md records why this
// exists: Milkdown's commonmark/GFM parser has no dedicated node for YAML
// front matter or math notation, so it reads their delimiters as ordinary
// commonmark syntax and silently reparses them into different *supported*
// content (a heading, a thematic break, escaped text) rather than leaving
// them inert. That is a contract failure the spec forbids, so these two
// constructs must never reach Milkdown at all. Detection walks the real
// mdast tree remark produces instead of pattern-matching raw text, so it
// does not misfire on a `---` thematic break elsewhere in a document.
//
// Display math (`$$` blocks) comes from remark-math. Inline math follows
// Pandoc's tex_math_dollars rule instead of remark-math's pairing, so prices
// such as "$650 to $1,000" are not read as math (Edison's decision,
// 22 Oct 2026). The rule: the opening `$` has a non-space character to its
// right, and the closing `$` has a non-space character to its left and is not
// followed by a digit.
const displayProcessor = unified()
  .use(remarkParse)
  .use(remarkFrontmatter, ["yaml"])
  .use(remarkGfm)
  .use(remarkMath);

const inlineProcessor = unified().use(remarkParse).use(remarkFrontmatter, ["yaml"]).use(remarkGfm);

type Positioned = {
  type: string;
  position?: { start: { offset?: number }; end: { offset?: number } };
  children?: Positioned[];
};

// The node types whose text is one run of inline content.
const INLINE_CONTAINERS = new Set(["paragraph", "heading", "tableCell"]);

export function classifyMarkdown(markdown: string): AdmissionResult {
  const reasons = new Set<BlockedReason>();

  visit(displayProcessor.parse(markdown), (node: { type: string }) => {
    if (node.type === "yaml") reasons.add("front-matter");
    if (node.type === "math") reasons.add("math");
  });

  visit(inlineProcessor.parse(markdown) as Positioned, (node: Positioned) => {
    if (!INLINE_CONTAINERS.has(node.type)) return;
    if (containsInlineMath(maskedSource(markdown, node))) reasons.add("math");
    return "skip";
  });

  if (reasons.size === 0) return { status: "admitted" };
  return { status: "blocked", reasons: [...reasons] };
}

// The container's source with every inline code span blanked out, so a `$`
// inside backticks never counts.
function maskedSource(markdown: string, container: Positioned): string {
  const start = container.position?.start.offset ?? 0;
  const end = container.position?.end.offset ?? start;
  const chars = markdown.slice(start, end).split("");
  visit(container, "inlineCode", (code: Positioned) => {
    const from = (code.position?.start.offset ?? start) - start;
    const to = (code.position?.end.offset ?? start) - start;
    for (let i = from; i < to; i += 1) chars[i] = " ";
  });
  return chars.join("");
}

function containsInlineMath(text: string): boolean {
  const isDelimiter = (i: number) => text[i] === "$" && text[i - 1] !== "\\";
  const isSpace = (c: string | undefined) => c === undefined || /\s/.test(c);
  for (let open = 0; open < text.length; open += 1) {
    if (!isDelimiter(open) || isSpace(text[open + 1])) continue;
    if (text[open + 1] === "$") {
      // An inline `$$...$$` is display math in Pandoc.
      if (text.indexOf("$$", open + 2) !== -1) return true;
      open += 1;
      continue;
    }
    for (let close = open + 2; close < text.length; close += 1) {
      if (!isDelimiter(close)) continue;
      if (!isSpace(text[close - 1]) && !/[0-9]/.test(text[close + 1] ?? "")) return true;
    }
  }
  return false;
}
