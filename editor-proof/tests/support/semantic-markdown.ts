import { unified } from "unified";
import remarkParse from "remark-parse";
import remarkGfm from "remark-gfm";

type AstNode = Record<string, unknown> | AstNode[] | unknown;

function stripPositions(node: AstNode): AstNode {
  if (Array.isArray(node)) return node.map(stripPositions);
  if (node && typeof node === "object") {
    const { position: _position, ...rest } = node as Record<string, unknown>;
    for (const key of Object.keys(rest)) {
      rest[key] = stripPositions(rest[key]);
    }
    return rest;
  }
  return node;
}

// Inline marks that commute: `~~*x*~~` and `*~~x~~*` mean the same thing,
// but mdast represents each nesting order as a structurally different tree.
// Milkdown's serializer does not preserve the original nesting order for
// these, so comparing "semantic structure" has to canonicalize it first.
const COMMUTING_MARK_TYPES = new Set(["emphasis", "strong", "delete"]);

function canonicalizeMarkOrder(node: AstNode): AstNode {
  if (Array.isArray(node)) return node.map(canonicalizeMarkOrder);
  if (!node || typeof node !== "object") return node;

  const record = node as Record<string, unknown>;
  if (Array.isArray(record.children)) {
    record.children = (record.children as AstNode[]).map(canonicalizeMarkOrder);
  }

  const type = record.type;
  if (typeof type !== "string" || !COMMUTING_MARK_TYPES.has(type)) return record;

  const chain: string[] = [type];
  let innermost = record;
  while (
    Array.isArray(innermost.children) &&
    innermost.children.length === 1 &&
    typeof (innermost.children[0] as Record<string, unknown>).type === "string" &&
    COMMUTING_MARK_TYPES.has(
      (innermost.children[0] as Record<string, unknown>).type as string,
    )
  ) {
    innermost = innermost.children[0] as Record<string, unknown>;
    chain.push(innermost.type as string);
  }

  if (chain.length === 1) return record;

  chain.sort();
  let rebuilt: Record<string, unknown> = { type: chain[chain.length - 1], children: innermost.children };
  for (let i = chain.length - 2; i >= 0; i -= 1) {
    rebuilt = { type: chain[i], children: [rebuilt] };
  }
  return rebuilt;
}

/**
 * Parses Markdown into its semantic (mdast) structure, ignoring source
 * position, any equivalent-syntax differences remark itself already
 * normalizes away (bullet marker character, emphasis marker character,
 * etc), and nesting-order differences between commuting inline marks.
 */
export function parseSemanticMarkdown(markdown: string): AstNode {
  const tree = unified().use(remarkParse).use(remarkGfm).parse(markdown);
  const stripped = stripPositions(tree as unknown as Record<string, unknown>);
  return canonicalizeMarkOrder(stripped);
}
