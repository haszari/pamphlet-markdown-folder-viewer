export type ThemeReferenceLink = {
  label: string;
  url: string;
};

export type ThemeReferenceHook = {
  concept: string;
  selectors: string[];
  description: string;
};

export type ThemeReferenceHookGroup = {
  title: string;
  description: string;
  links: ThemeReferenceLink[];
  hooks: ThemeReferenceHook[];
};

export type ThemeReferenceData = {
  links: ThemeReferenceLink[];
  tokenDescriptions: Record<string, string>;
  tokenExamples: Record<string, string>;
  inheritedHookGroups: ThemeReferenceHookGroup[];
};

export const themeReferenceData: ThemeReferenceData = {
  links: [
    {
      label: "CSS custom properties",
      url: "https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Cascading_variables/Using_custom_properties",
    },
    {
      label: "prefers-color-scheme",
      url: "https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@media/prefers-color-scheme",
    },
    {
      label: "browser color-scheme",
      url: "https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/color-scheme",
    },
    {
      label: "font-family",
      url: "https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/font-family",
    },
    {
      label: "url()",
      url: "https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/url",
    },
    {
      label: "CSS length values",
      url: "https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/length",
    },
    {
      label: "CSS hex colours",
      url: "https://developer.mozilla.org/en-US/docs/Web/CSS/hex-color",
    },
    {
      label: "CSS selectors",
      url: "https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_selectors",
    },
    {
      label: "highlight.js theme guide",
      url: "https://highlightjs.readthedocs.io/en/latest/theme-guide.html",
    },
    {
      label: "Font Book User Guide",
      url: "https://support.apple.com/guide/font-book/welcome/mac",
    },
  ],
  tokenDescriptions: {
    "--pamphlet-background":
      "Primary background for rendered content and the workspace base.",
    "--pamphlet-foreground": "Primary text colour.",
    "--pamphlet-muted-foreground": "Subdued text colour.",
    "--pamphlet-accent": "Accent colour for links and selected/action states.",
    "--pamphlet-appearance": "Theme appearance: light, dark, or adaptive.",
    "--pamphlet-window-background":
      "Optional background override for sidebar and tab UI.",
    "--pamphlet-selection-background": "Selection and active item background.",
    "--pamphlet-border": "Borders and dividers.",
    "--pamphlet-font-family": "Rendered content body font stack.",
    "--pamphlet-heading-font-family": "Rendered content heading font stack.",
    "--pamphlet-monospace-font-family":
      "Rendered content code/source/table font stack.",
    "--pamphlet-code-background": "Inline code and fenced code background.",
    "--pamphlet-quote-background": "Blockquote and quoted box background.",
    "--pamphlet-workspace-title":
      "Workspace-only title label used in the window title.",
    "--pamphlet-badge": "Set to none to hide an inherited badge.",
    "--pamphlet-badge-emoji": "Decorative badge emoji or short text.",
    "--pamphlet-badge-image": 'Decorative badge image path using url("...").',
    "--pamphlet-badge-placement":
      "Badge corner: top-left, top-right, bottom-left, or bottom-right.",
    "--pamphlet-badge-anchor": "Badge anchor: window or content.",
    "--pamphlet-badge-margin-x": "Horizontal badge margin.",
    "--pamphlet-badge-margin-y": "Vertical badge margin.",
    "--pamphlet-badge-opacity": "Badge opacity.",
    "--pamphlet-badge-size": "Badge rendered size.",
  },
  tokenExamples: {
    "--pamphlet-background": "#ffffff",
    "--pamphlet-foreground": "#1f2328",
    "--pamphlet-muted-foreground": "#66707a",
    "--pamphlet-accent": "#0969da",
    "--pamphlet-appearance": "adaptive",
    "--pamphlet-window-background": "#f6f8fa",
    "--pamphlet-selection-background": "#dbeafe",
    "--pamphlet-border": "#d0d7de",
    "--pamphlet-font-family": '"Avenir Next", system-ui, sans-serif',
    "--pamphlet-heading-font-family": "Georgia, serif",
    "--pamphlet-monospace-font-family": '"SF Mono", Menlo, monospace',
    "--pamphlet-code-background": "#eff2f5",
    "--pamphlet-quote-background": "#f6f8fa",
    "--pamphlet-workspace-title": '"Banana Corp"',
    "--pamphlet-badge": "none",
    "--pamphlet-badge-emoji": '"🍌"',
    "--pamphlet-badge-image": 'url("badge.png")',
    "--pamphlet-badge-placement": "bottom-left",
    "--pamphlet-badge-anchor": "window",
    "--pamphlet-badge-margin-x": "1.5rem",
    "--pamphlet-badge-margin-y": "1.5rem",
    "--pamphlet-badge-opacity": "0.12",
    "--pamphlet-badge-size": "6rem",
  },
  inheritedHookGroups: [
    {
      title: "Markdown headings",
      description:
        "Markdown headings render as HTML heading elements inside .markdown.",
      links: [
        {
          label: "MDN heading elements",
          url: "https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/Heading_Elements",
        },
      ],
      hooks: [
        {
          concept: "Heading 1",
          selectors: [".markdown h1"],
          description: "Markdown # heading.",
        },
        {
          concept: "Heading 2",
          selectors: [".markdown h2"],
          description: "Markdown ## heading.",
        },
        {
          concept: "Heading 3",
          selectors: [".markdown h3"],
          description: "Markdown ### heading.",
        },
        {
          concept: "Heading 4",
          selectors: [".markdown h4"],
          description: "Markdown #### heading.",
        },
        {
          concept: "Heading 5",
          selectors: [".markdown h5"],
          description: "Markdown ##### heading.",
        },
        {
          concept: "Heading 6",
          selectors: [".markdown h6"],
          description: "Markdown ###### heading.",
        },
      ],
    },
    {
      title: "Markdown flow content",
      description:
        "Common Markdown blocks render as standard HTML elements inside .markdown.",
      links: [
        {
          label: "MDN HTML elements",
          url: "https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements",
        },
      ],
      hooks: [
        {
          concept: "Paragraph",
          selectors: [".markdown p"],
          description: "Normal Markdown paragraph text.",
        },
        {
          concept: "Unordered list",
          selectors: [".markdown ul"],
          description: "Bulleted Markdown list.",
        },
        {
          concept: "Ordered list",
          selectors: [".markdown ol"],
          description: "Numbered Markdown list.",
        },
        {
          concept: "List item",
          selectors: [".markdown li"],
          description: "A single item inside an ordered or unordered list.",
        },
        {
          concept: "Blockquote",
          selectors: [".markdown blockquote"],
          description: "Markdown quote block.",
        },
        {
          concept: "Horizontal rule",
          selectors: [".markdown hr"],
          description: "Markdown thematic break.",
        },
      ],
    },
    {
      title: "Markdown inline content",
      description:
        "Inline Markdown renders as standard inline HTML elements inside .markdown.",
      links: [
        {
          label: "MDN inline text semantics",
          url: "https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements#inline_text_semantics",
        },
      ],
      hooks: [
        {
          concept: "Link",
          selectors: [".markdown a"],
          description: "Markdown link.",
        },
        {
          concept: "Inline code",
          selectors: [".markdown code"],
          description: "Backtick inline code.",
        },
        {
          concept: "Strong text",
          selectors: [".markdown strong"],
          description: "Bold Markdown text.",
        },
        {
          concept: "Emphasis",
          selectors: [".markdown em"],
          description: "Italic Markdown text.",
        },
      ],
    },
    {
      title: "Markdown media and tables",
      description:
        "Markdown images and tables render as HTML media and table elements inside .markdown.",
      links: [
        {
          label: "MDN image element",
          url: "https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/img",
        },
        {
          label: "MDN table element",
          url: "https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/table",
        },
      ],
      hooks: [
        {
          concept: "Image",
          selectors: [".markdown img"],
          description: "Markdown image.",
        },
        {
          concept: "Table",
          selectors: [".markdown table"],
          description: "Markdown table.",
        },
        {
          concept: "Table head",
          selectors: [".markdown thead"],
          description: "Header section of a Markdown table.",
        },
        {
          concept: "Table body",
          selectors: [".markdown tbody"],
          description: "Body section of a Markdown table.",
        },
        {
          concept: "Table row",
          selectors: [".markdown tr"],
          description: "Row in a Markdown table.",
        },
        {
          concept: "Table header cell",
          selectors: [".markdown th"],
          description: "Header cell in a Markdown table.",
        },
        {
          concept: "Table cell",
          selectors: [".markdown td"],
          description: "Body cell in a Markdown table.",
        },
      ],
    },
    {
      title: "Code and syntax highlighting",
      description:
        "Fenced code and source views use pre/code elements and highlight.js classes.",
      links: [
        {
          label: "highlight.js theme guide",
          url: "https://highlightjs.readthedocs.io/en/latest/theme-guide.html",
        },
        {
          label: "MDN pre element",
          url: "https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/pre",
        },
        {
          label: "MDN code element",
          url: "https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/code",
        },
      ],
      hooks: [
        {
          concept: "Preformatted block",
          selectors: [".markdown pre", ".source pre"],
          description: "Fenced code block or source view block.",
        },
        {
          concept: "Code text",
          selectors: [".markdown code", ".source code"],
          description: "Inline code, fenced code, or source view code.",
        },
        {
          concept: "Highlighted code root",
          selectors: [".hljs"],
          description: "highlight.js root class.",
        },
        {
          concept: "Keyword or type",
          selectors: [".hljs-keyword", ".hljs-type"],
          description: "Language keywords and types.",
        },
        {
          concept: "String",
          selectors: [".hljs-string"],
          description: "String literals.",
        },
        {
          concept: "Comment",
          selectors: [".hljs-comment"],
          description: "Comments.",
        },
        {
          concept: "Number or literal",
          selectors: [".hljs-number", ".hljs-literal"],
          description: "Numbers and literals.",
        },
        {
          concept: "Function or title",
          selectors: [".hljs-title", ".hljs-function"],
          description: "Function names and other titled symbols.",
        },
        {
          concept: "Attribute or variable",
          selectors: [".hljs-attr", ".hljs-variable"],
          description: "Attributes and variables.",
        },
        {
          concept: "Added or removed text",
          selectors: [".hljs-addition", ".hljs-deletion"],
          description: "Diff-style additions and deletions.",
        },
      ],
    },
  ],
};
