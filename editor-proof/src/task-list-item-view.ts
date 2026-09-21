import { $view } from "@milkdown/kit/utils";
import { extendListItemSchemaForTask } from "@milkdown/kit/preset/gfm";
import type { NodeViewConstructor } from "@milkdown/kit/prose/view";

const isTaskItem = (attrs: { checked: boolean | null }) => attrs.checked != null;

/**
 * Milkdown's gfm preset renders a task list item's checked state only as a
 * `data-checked` DOM attribute; it has no interactive checkbox. Direct
 * formatted editing of task state needs one, so this node view adds a real
 * `<input type="checkbox">` for task items and toggles the node's `checked`
 * attribute through a ProseMirror transaction on change.
 *
 * A plain (non-task) list item keeps the exact DOM shape the default schema
 * produces (`<li>` as both the outer element and the content hole), so this
 * view only changes behavior for task items.
 */
export const taskListItemView = $view(
  extendListItemSchemaForTask.node,
  (): NodeViewConstructor => {
    return (initialNode, view, getPos) => {
      let node = initialNode;
      const applyListAttrs = (li: HTMLElement) => {
        li.dataset.label = node.attrs.label;
        li.dataset.listType = node.attrs.listType;
        li.dataset.spread = String(node.attrs.spread);
      };

      if (!isTaskItem(node.attrs)) {
        const li = document.createElement("li");
        applyListAttrs(li);
        return {
          dom: li,
          contentDOM: li,
          update: (updatedNode) => {
            if (updatedNode.type !== node.type) return false;
            if (isTaskItem(updatedNode.attrs)) return false;
            node = updatedNode;
            applyListAttrs(li);
            return true;
          },
        };
      }

      const li = document.createElement("li");
      const content = document.createElement("div");
      const checkbox = document.createElement("input");
      checkbox.type = "checkbox";
      // Prevent the browser from moving the ProseMirror selection into the
      // checkbox before the change handler runs.
      checkbox.addEventListener("mousedown", (event) => event.preventDefault());
      checkbox.addEventListener("change", () => {
        const pos = getPos();
        if (pos == null) return;
        const tr = view.state.tr.setNodeMarkup(pos, undefined, {
          ...node.attrs,
          checked: checkbox.checked,
        });
        view.dispatch(tr);
      });

      const applyTaskAttrs = () => {
        applyListAttrs(li);
        li.dataset.itemType = "task";
        li.dataset.checked = String(node.attrs.checked);
        checkbox.checked = Boolean(node.attrs.checked);
      };

      li.appendChild(checkbox);
      li.appendChild(content);
      applyTaskAttrs();

      return {
        dom: li,
        contentDOM: content,
        update: (updatedNode) => {
          if (updatedNode.type !== node.type) return false;
          if (!isTaskItem(updatedNode.attrs)) return false;
          node = updatedNode;
          applyTaskAttrs();
          return true;
        },
      };
    };
  },
);
