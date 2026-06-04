export type RendererThemeHook = {
  selector: string;
  name: string;
  description: string;
};

export const rendererThemeHooks: RendererThemeHook[] = [
  {
    selector: ".view",
    name: "Rendered view",
    description: "Root element for every rendered file view.",
  },
  {
    selector: ".markdown",
    name: "Markdown view",
    description: "Root element for rendered Markdown content.",
  },
  {
    selector: ".source",
    name: "Source view",
    description: "Root element for plain text and highlighted source files.",
  },
  {
    selector: ".table",
    name: "Table view",
    description: "Root element for CSV and TSV tables.",
  },
  {
    selector: ".image",
    name: "Image view",
    description: "Root element for image previews.",
  },
  {
    selector: ".table-scroll",
    name: "Scrollable table",
    description: "Scroll container around CSV and TSV table output.",
  },
];
