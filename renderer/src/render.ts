import DOMPurify from "dompurify";
import hljs from "highlight.js/lib/common";
import MarkdownIt from "markdown-it";
import footnote from "markdown-it-footnote";
import taskLists from "markdown-it-task-lists";
import Papa from "papaparse";
import "highlight.js/styles/github.css";
import "./styles.css";
import {
  resolveUrl,
  rewriteEmbeddedAssetUrl,
  type UrlPolicy,
} from "./urlPolicy";

export type RenderMode = "markdown" | "text" | "code" | "table" | "image";

export type RenderPayload = {
  mode: RenderMode;
  content?: string;
  language?: string;
  imageUrl?: string;
  fileName: string;
  filePath: string;
  workspaceToken: string;
  refreshVersion: number;
  table?: {
    delimiter: "," | "\t";
    firstRowHeader: boolean;
  };
};

const markdown = new MarkdownIt({
  html: true,
  linkify: true,
  typographer: false,
  highlight(code, language) {
    if (language && hljs.getLanguage(language)) {
      return hljs.highlight(code, { language }).value;
    }
    return escapeHtml(code);
  },
})
  .use(footnote)
  .use(taskLists, { enabled: false, label: true, labelAfter: true });

export function render(payload: RenderPayload): void {
  const root = document.getElementById("root");
  if (!root) return;

  const policy: UrlPolicy = {
    workspaceToken: payload.workspaceToken,
    filePath: payload.filePath,
    refreshVersion: payload.refreshVersion,
  };

  root.innerHTML = "";
  root.appendChild(renderElement(payload, policy));
  installClickRouting(root, policy);
}

function renderElement(payload: RenderPayload, policy: UrlPolicy): HTMLElement {
  switch (payload.mode) {
    case "markdown":
      return renderMarkdown(payload.content ?? "", policy);
    case "text":
      return renderSource(payload.content ?? "", undefined);
    case "code":
      return renderSource(payload.content ?? "", payload.language);
    case "table":
      return renderTable(
        payload.content ?? "",
        payload.table?.delimiter ?? ",",
        payload.table?.firstRowHeader ?? true,
      );
    case "image":
      return renderImage(payload.imageUrl ?? "", payload.fileName, policy);
  }
}

function renderMarkdown(content: string, policy: UrlPolicy): HTMLElement {
  const view = document.createElement("main");
  view.className = "view markdown";
  view.innerHTML = DOMPurify.sanitize(markdown.render(content), {
    USE_PROFILES: { html: true },
    ADD_ATTR: ["target"],
  });
  rewriteEmbeddedAssets(view, policy);
  return view;
}

function renderSource(
  content: string,
  language: string | undefined,
): HTMLElement {
  const view = document.createElement("main");
  view.className = "view source";
  const pre = document.createElement("pre");
  const code = document.createElement("code");

  if (language && hljs.getLanguage(language)) {
    code.innerHTML = hljs.highlight(content, { language }).value;
    code.className = `language-${language}`;
  } else {
    code.textContent = content;
  }

  pre.appendChild(code);
  view.appendChild(pre);
  linkifyAbsoluteUrls(view);
  return view;
}

function renderTable(
  content: string,
  delimiter: "," | "\t",
  firstRowHeader: boolean,
): HTMLElement {
  const view = document.createElement("main");
  view.className = "view table";
  const scroll = document.createElement("div");
  scroll.className = "table-scroll";
  const table = document.createElement("table");
  const parsed = Papa.parse<string[]>(content, {
    delimiter,
    skipEmptyLines: false,
  });
  const rows = parsed.data.filter((row) => row.some((cell) => cell.length > 0));

  if (firstRowHeader && rows.length > 0) {
    const thead = document.createElement("thead");
    thead.appendChild(renderRow(rows[0], "th"));
    table.appendChild(thead);
  }

  const tbody = document.createElement("tbody");
  for (const row of firstRowHeader ? rows.slice(1) : rows) {
    tbody.appendChild(renderRow(row, "td"));
  }
  table.appendChild(tbody);
  scroll.appendChild(table);
  view.appendChild(scroll);
  linkifyAbsoluteUrls(view);
  return view;
}

function renderImage(
  imageUrl: string,
  fileName: string,
  policy: UrlPolicy,
): HTMLElement {
  const view = document.createElement("main");
  view.className = "view image";
  const image = document.createElement("img");
  image.alt = fileName;
  image.src = rewriteEmbeddedAssetUrl(imageUrl, policy);
  view.appendChild(image);
  return view;
}

function renderRow(row: string[], cellName: "td" | "th"): HTMLTableRowElement {
  const tr = document.createElement("tr");
  for (const value of row) {
    const cell = document.createElement(cellName);
    cell.textContent = value;
    tr.appendChild(cell);
  }
  return tr;
}

function rewriteEmbeddedAssets(root: HTMLElement, policy: UrlPolicy): void {
  for (const image of Array.from(root.querySelectorAll("img[src]"))) {
    const src = image.getAttribute("src");
    if (src) image.setAttribute("src", rewriteEmbeddedAssetUrl(src, policy));
  }
}

function installClickRouting(root: HTMLElement, policy: UrlPolicy): void {
  root.onclick = (event) => {
    const target = event.target as HTMLElement | null;
    const anchor = target?.closest("a[href]") as HTMLAnchorElement | null;
    if (!anchor) return;

    event.preventDefault();
    const resolved = resolveUrl(anchor.getAttribute("href") ?? "", policy);
    window.webkit?.messageHandlers?.linkClick?.postMessage({
      href: resolved.original,
      isExternal: resolved.isExternal,
      isWorkspaceLocal: resolved.isWorkspaceLocal,
      resolvedPath: resolved.resolvedPath ?? null,
      metaKey: event.metaKey,
    });
  };
}

function linkifyAbsoluteUrls(root: HTMLElement): void {
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  const textNodes: Text[] = [];
  while (walker.nextNode()) {
    textNodes.push(walker.currentNode as Text);
  }

  for (const node of textNodes) {
    const parts = node.data.split(/(https?:\/\/[^\s<>"']+|mailto:[^\s<>"']+)/g);
    if (parts.length === 1) continue;
    const fragment = document.createDocumentFragment();
    for (const part of parts) {
      if (/^(https?:\/\/|mailto:)/.test(part)) {
        const anchor = document.createElement("a");
        anchor.href = part;
        anchor.textContent = part;
        fragment.appendChild(anchor);
      } else {
        fragment.appendChild(document.createTextNode(part));
      }
    }
    node.replaceWith(fragment);
  }
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}
