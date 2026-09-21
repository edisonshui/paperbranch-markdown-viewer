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
// mdast tree remark produces (via remark-frontmatter and remark-math)
// instead of pattern-matching raw text, so it does not misfire on content
// that merely looks similar, such as a `---` thematic break elsewhere in a
// document or a literal `$` used for currency.
const processor = unified()
  .use(remarkParse)
  .use(remarkFrontmatter, ["yaml"])
  .use(remarkGfm)
  .use(remarkMath);

export function classifyMarkdown(markdown: string): AdmissionResult {
  const tree = processor.parse(markdown);
  const reasons = new Set<BlockedReason>();

  visit(tree, (node: { type: string }) => {
    if (node.type === "yaml") reasons.add("front-matter");
    if (node.type === "math" || node.type === "inlineMath") reasons.add("math");
  });

  if (reasons.size === 0) return { status: "admitted" };
  return { status: "blocked", reasons: [...reasons] };
}
