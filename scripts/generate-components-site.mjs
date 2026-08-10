import { mkdir, readdir, readFile, writeFile } from "node:fs/promises";
import { basename, join, resolve } from "node:path";
import { components, groups, skins } from "./component-catalog.mjs";

const projectRoot = resolve(new URL("..", import.meta.url).pathname);
const siteRoot = resolve(process.argv[2] || join(projectRoot, "build/site"));
const apiIndex = join(projectRoot, "docs/api/search-index.js");

const escapeHtml = (value) => String(value)
  .replaceAll("&", "&amp;").replaceAll("<", "&lt;")
  .replaceAll(">", "&gt;").replaceAll('"', "&quot;");

const packageName = (item) => {
  const source = item.sourceSlug || item.slug.replaceAll("-", "_");
  const suffix = source.split("_")
    .map((part) => part[0].toUpperCase() + part.slice(1)).join("_");
  return `Flyology_TUI.Components.${suffix}`;
};

async function readApiEntries() {
  const source = await readFile(apiIndex, "utf8");
  const prefix = "window.FlyologyApiSearch = ";
  if (!source.startsWith(prefix) || !source.trimEnd().endsWith(";")) {
    throw new Error("unexpected GNATdoc search-index.js format");
  }
  return JSON.parse(source.slice(prefix.length).trim().replace(/;$/, ""));
}

async function verifyCatalog() {
  const sourceFiles = await readdir(join(projectRoot, "src"));
  const publicComponents = sourceFiles
    .filter((name) => /^flyology_tui-components-.+\.ads$/.test(name))
    .map((name) => name
      .replace("flyology_tui-components-", "").replace(".ads", ""))
    .sort();
  const catalogComponents = components
    .map((item) => item.sourceSlug || item.slug.replaceAll("-", "_"))
    .sort();
  if (JSON.stringify(publicComponents) !== JSON.stringify(catalogComponents)) {
    const missing = publicComponents.filter((name) =>
      !catalogComponents.includes(name));
    const extra = catalogComponents.filter((name) =>
      !publicComponents.includes(name));
    throw new Error(
      `component catalog mismatch; missing=[${missing}], extra=[${extra}]`
    );
  }
}

function navigation(prefix, current) {
  const link = (id, href, label) =>
    `<li><a href="${prefix}${href}"${current === id ? ' aria-current="page"' : ""}>${label}</a></li>`;
  return `<header class="site-header">
      <nav class="site-nav" aria-label="Primary navigation">
        <a class="brand" href="${prefix}" aria-label="Flyology TUI home">
          <img src="${prefix}assets/brand/flyology-mark-transparent.svg" alt="">
          <span>Flyology TUI</span>
        </a>
        <ul class="nav-links" data-nav-links>
          ${link("overview", "", "Overview")}
          ${link("guide", "guide/", "Guide")}
          ${link("components", "components/", "Components")}
          ${link("architecture", "architecture/", "Architecture")}
          ${link("api", "api/", "API")}
          <li><details class="nav-dropdown" data-nav-dropdown>
            <summary>Ecosystem <svg aria-hidden="true" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.5"><path d="m2.5 4.5 3.5 3 3.5-3"/></svg></summary>
            <ul class="nav-dropdown-menu">
              <li><a href="https://flyology.org/">Runtime</a></li>
              <li><a href="https://http.flyology.org/">HTTP</a></li>
              <li><a href="https://postgres.flyology.org/">Postgres</a></li>
            </ul>
          </details></li>
          <li><a href="https://github.com/flyology-ada/flyology-tui">GitHub</a></li>
        </ul>
        <div class="nav-tools">
          <button class="icon-button" type="button" data-theme-toggle>
            <span class="visually-hidden" data-theme-label>Change theme</span>
            <svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12 3v2.2M12 18.8V21M3 12h2.2M18.8 12H21M5.64 5.64 7.2 7.2M16.8 16.8l1.56 1.56M18.36 5.64 16.8 7.2M7.2 16.8l-1.56 1.56"/><circle cx="12" cy="12" r="4"/></svg>
          </button>
          <button class="menu-button" type="button" data-menu-toggle aria-expanded="false" aria-label="Toggle navigation"><svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M4 7h16M4 12h16M4 17h16"/></svg></button>
        </div>
      </nav>
    </header>`;
}

function footer(prefix) {
  return `<footer class="site-footer"><div class="footer-inner">
      <span>Flyology TUI is experimental and dual-licensed under MIT or Apache-2.0.</span>
      <div class="footer-links">
        <a href="https://github.com/flyology-ada/flyology-tui">Source</a>
        <a href="${prefix}guide/">Guide</a>
        <a href="${prefix}components/">Components</a>
        <a href="${prefix}api/">API reference</a>
      </div>
    </div></footer>`;
}

function sideNavigation(activeSlug) {
  return `<nav class="component-sidebar" aria-label="Component catalog">
    <a class="component-sidebar-index" href="../">All components</a>
    ${groups.map((group) => `<section><h2>${group}</h2><ul>${components
      .filter((item) => item.group === group)
      .map((item) => `<li><a href="../${item.slug}/"${item.slug === activeSlug ? ' aria-current="page"' : ""}>${item.title}</a></li>`)
      .join("")}</ul></section>`).join("")}
  </nav>`;
}

function previewRows(kind) {
  const rows = {
    accordion: [["▼ Overview", "selected"], ["  Stable IDs and external bodies", "normal"], ["▶ Details", "control"], ["▶ Examples", "control"]],
    breadcrumbs: [["flyology / tui / components / Buttons", "accent"], ["← ancestor", "muted"]],
    button: [["      Run command      ", "success"], ["                        ", "shadow"], ["Enter or click to activate", "muted"]],
    chat: [[" you ", "accent"], ["Build a bounded chat surface.", "control"], ["                              assistant ", "success"], ["Messages can contain components.", "normal"]],
    checkbox: [["[ ] Enable telemetry", "control"], ["[X] Keep bounded history", "selected"], ["[-] Inherited policy", "control"]],
    dock: [["[Project]│ editor workspace │[Outline]", "accent"], ["         │                  │         ", "normal"], ["─────────┴──────────────────┴─────────", "border"], ["[ Problems — collapsed ]", "muted"]],
    dropdown: [["[ Charm dark            ▾ ]", "control"], ["  Charm", "normal"], ["› Charm dark", "selected"], ["  Turbo Vision", "normal"]],
    form: [["Name     Ada programmer", "input"], ["Project  Flyology TUI", "input"], ["Mode     [ Declarative ▾ ]", "control"]],
    gradient: [["████████████████████████████████", "gradient"], ["low          semantic          high", "muted"]],
    help: [["tab  focus    arrows  choose", "normal"], ["f6   skin     ctrl-c  quit", "accent"]],
    indicators: [["[bounded]  aggregate     50%", "success"], ["██████████░░░░░░░░░░", "accent"], ["RUNNING │ paused tests │ ring:32", "normal"]],
    interaction: [["Handled  Changed  Activated", "accent"], ["  TRUE     TRUE      FALSE", "control"], ["Capture: Acquire", "success"]],
    list: [["› Typed messages", "selected"], ["  Declarative views", "control"], ["  Bounded commands", "control"], ["  Headless tests", "control"]],
    markdownEditor: [["# Flyology TUI Markdown", "accent"], ["Edit **bounded source** beside preview.", "input"], ["────────────────────────────────", "border"], ["Flyology TUI Markdown", "success"]],
    markdown: [["Flyology TUI Markdown", "accent"], ["Bounded source with live structure", "normal"], ["☑ Unicode-aware rendering", "control"], ["Ada documentation →", "success"]],
    menubar: [["File  Edit  View  Navigate  Help", "normal"], ["┌ File ──────────────────┐", "border"], ["│ Open…            Ctrl+O│", "selected"], ["│ Exit             Ctrl+Q│", "control"]],
    panels: [["pane A        ║ pane B      ║ pane C", "normal"], ["              ║             ║       ", "normal"], ["drag or focus a shared boundary", "muted"]],
    progress: [["Build", "accent"], ["████████████░░░░░░░░  58%", "success"]],
    progressGroup: [["› Build    ███████████░░", "selected"], ["  Tests    ███████░░░░░░", "control"], ["  Deploy   ◐", "normal"]],
    radio: [["(•) Alpha", "selected"], ["( ) Beta", "control"], ["( ) Gamma", "control"]],
    scrollbar: [["▲", "accent"], ["▒", "control"], ["█", "selected"], ["▒", "control"], ["▼", "accent"]],
    selector: [["[ ] Alpha", "control"], ["[X] Beta", "selected"], ["[X] Gamma", "selected"]],
    sparkline: [["▁▂▃▅▇▆▄▃▅▇█▆▃▂", "success"], ["bounded numeric suffix", "muted"]],
    spinner: [["◒ Measuring wrapped output", "accent"], ["caller-owned tick events", "muted"]],
    split: [["source pane       │ preview pane", "normal"], ["                  │             ", "normal"], ["      shared draggable divider", "muted"]],
    stream: [["assistant · streaming", "accent"], ["Measuring wrapped output synchronously…", "normal"], ["Updating follow-tail through one owner.", "success"]],
    syntax: [["procedure Hello is", "accent"], ["begin", "success"], ["   Put_Line (\"Hello from Ada\");", "input"], ["end Hello;", "success"]],
    table: [["Component       Status", "accent"], ["runtime         active", "control"], ["POSIX backend   ready", "selected"], ["views           bounded", "control"]],
    tabs: [["[Basics]  Controls  Navigation  Editors", "selected"], ["active identity survives responsive clipping", "muted"]],
    textarea: [["1  Bounded multiline text", "input"], ["2  with selection, history,", "input"], ["3  and soft wrapping.", "selected"]],
    textinput: [["Name", "accent"], ["Ada programmer▏", "input"]],
    tree: [["▼ flyology-tui", "selected"], ["  ▼ src", "control"], ["      components", "control"], ["    examples", "normal"]],
    viewport: [["BOUND VIEWPORT · content and scrollbars", "normal"], ["Arrow keys move content; thumbs follow.", "normal"], ["◀▒▒▒▒▒▒████▒▒▒▒▒▒▒▒▒▒▒▒▒▒▶", "control"]],
    window: [["[■]════════ Activity ══════════", "border"], ["║ Application owns z-order.   ║", "normal"], ["║ Children remain external.   ║", "normal"], ["╚════════════════════════════◆", "border"]]
  };
  const value = rows[kind];
  if (!value) throw new Error(`missing preview rows for ${kind}`);
  return value;
}

function svgPreview(item, skin) {
  const c = skin.colors;
  const textColor = (role) => ({
    normal: c.text, muted: c.muted, border: c.border,
    accent: skin.id === "turbo-vision" ? c.accent : c.accent,
    control: c.text, selected: skin.id === "charm-dark" ? c.text : "#101015",
    success: skin.id === "charm-dark" ? c.text : "#101015",
    input: skin.id === "turbo-vision" ? "#ffffff" : c.text,
    shadow: c.shadow, danger: c.danger, gradient: c.text
  }[role] || c.text);
  const background = (role) => ({
    control: c.control, selected: c.selected, success: c.success,
    input: skin.id === "turbo-vision" ? c.accent : c.control,
    shadow: c.shadow
  }[role] || "transparent");
  const rows = previewRows(item.kind);
  const top = skin.frame === "double" ? "╔" : "╭";
  const topRight = skin.frame === "double" ? "╗" : "╮";
  const bottom = skin.frame === "double" ? "╚" : "╰";
  const bottomRight = skin.frame === "double" ? "╝" : "╯";
  const horizontal = skin.frame === "double" ? "═" : "─";
  const vertical = skin.frame === "double" ? "║" : "│";
  const frameX = 36, frameY = 30, frameW = 648, frameH = 244;
  const panelX = 61, panelY = 68, panelW = 598, panelH = 170;
  const lineHeight = 29;
  const runWidth = (value) => [...value].length * 10.4;
  let y = 111;
  const rowMarkup = rows.map(([value, role]) => {
    const width = Math.min(runWidth(value) + 16, panelW - 38);
    const x = role === "scrollbar" ? panelX + panelW - 45 : panelX + 25;
    const rect = background(role) === "transparent" ? "" :
      `<rect x="${x - 7}" y="${y - 20}" width="${width}" height="25" rx="${skin.id === "turbo-vision" ? 0 : 4}" fill="${background(role)}"/>`;
    let content;
    if (role === "gradient") {
      content = `<defs><linearGradient id="ramp-${item.slug}-${skin.id}"><stop stop-color="${c.accent}"/><stop offset=".5" stop-color="${c.success}"/><stop offset="1" stop-color="${c.danger}"/></linearGradient></defs><rect x="${x - 7}" y="${y - 20}" width="340" height="23" fill="url(#ramp-${item.slug}-${skin.id})"/>`;
    } else {
      content = `${rect}<text x="${x}" y="${y}" fill="${textColor(role)}"${["accent", "selected", "success"].includes(role) ? ' font-weight="700"' : ""}>${escapeHtml(value)}</text>`;
    }
    y += lineHeight;
    return content;
  }).join("");
  const shadow = skin.id === "turbo-vision"
    ? `<rect x="${panelX + 10}" y="${panelY + 10}" width="${panelW}" height="${panelH}" fill="${c.shadow}"/>`
    : `<rect x="${panelX + 7}" y="${panelY + 9}" width="${panelW}" height="${panelH}" rx="9" fill="${c.shadow}" opacity=".65"/>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="720" height="304" viewBox="0 0 720 304" role="img" aria-labelledby="title desc">
    <title id="title">${escapeHtml(item.title)} in the ${escapeHtml(skin.label)} skin</title>
    <desc id="desc">Generated terminal preview for the Flyology TUI ${escapeHtml(item.title)} component.</desc>
    <rect width="720" height="304" rx="18" fill="${c.desktop}"/>
    <text x="${frameX}" y="23" fill="${skin.id === "turbo-vision" ? "#ffffff" : c.muted}" font-family="ui-monospace, SFMono-Regular, Menlo, Consolas, monospace" font-size="13">FLYOLOGY TUI · ${escapeHtml(skin.label.toUpperCase())}</text>
    ${shadow}
    <rect x="${panelX}" y="${panelY}" width="${panelW}" height="${panelH}" rx="${skin.id === "turbo-vision" ? 0 : 8}" fill="${c.panel}"/>
    <g fill="${c.border}" font-family="ui-monospace, SFMono-Regular, Menlo, Consolas, monospace" font-size="18" font-weight="700">
      <text x="${panelX - 1}" y="${panelY + 4}">${top}${horizontal.repeat(19)} ${escapeHtml(item.title)} ${horizontal.repeat(19)}${topRight}</text>
      <text x="${panelX - 1}" y="${panelY + panelH + 3}">${bottom}${horizontal.repeat(48)}${bottomRight}</text>
      <text x="${panelX - 2}" y="${panelY + 35}">${vertical}</text><text x="${panelX - 2}" y="${panelY + 68}">${vertical}</text><text x="${panelX - 2}" y="${panelY + 101}">${vertical}</text><text x="${panelX - 2}" y="${panelY + 134}">${vertical}</text>
      <text x="${panelX + panelW - 8}" y="${panelY + 35}">${vertical}</text><text x="${panelX + panelW - 8}" y="${panelY + 68}">${vertical}</text><text x="${panelX + panelW - 8}" y="${panelY + 101}">${vertical}</text><text x="${panelX + panelW - 8}" y="${panelY + 134}">${vertical}</text>
    </g>
    <g font-family="ui-monospace, SFMono-Regular, Menlo, Consolas, monospace" font-size="18">${rowMarkup}</g>
    <text x="${frameX}" y="291" fill="${skin.id === "turbo-vision" ? "#ffffff" : c.muted}" font-family="ui-monospace, SFMono-Regular, Menlo, Consolas, monospace" font-size="12">generated from the component catalog on every site build</text>
  </svg>`;
}

function skinSwitcher(item) {
  const attrs = skins.map((skin) =>
    `data-src-${skin.id}="images/${skin.id}.svg"`).join(" ");
  return `<div class="skin-preview" data-skin-preview>
    <div class="skin-preview-toolbar">
      <div><span class="eyebrow">Generated preview</span><strong data-skin-current>${skins[0].label}</strong></div>
      <div class="segmented-control" role="group" aria-label="Preview skin">
        ${skins.map((skin, index) => `<button type="button" data-skin-choice="${skin.id}" aria-pressed="${index === 0}">${skin.label}</button>`).join("")}
      </div>
    </div>
    <img src="images/${skins[0].id}.svg" ${attrs} data-skin-image alt="${escapeHtml(item.title)} rendered in the ${skins[0].label} skin">
    <p class="preview-note">All four SVG previews are regenerated during every site build. The switch changes only the borrowed render-time skin.</p>
  </div>`;
}

function componentPage(item, apiHref) {
  const packageId = packageName(item);
  return `<!doctype html>
<html lang="en"><head>
  <meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="${escapeHtml(item.summary)}">
  <meta name="theme-color" content="#241b35">
  <title>${escapeHtml(item.title)} · Flyology TUI components</title>
  <link rel="canonical" href="https://tui.flyology.org/components/${item.slug}/">
  <link rel="icon" href="../../assets/brand/flyology-primary-icon.svg" type="image/svg+xml">
  <link rel="stylesheet" href="../../assets/styles/site.css"><link rel="stylesheet" href="../../assets/styles/tui.css">
  <script src="../../assets/scripts/ada-highlight.js"></script><script src="../../assets/scripts/site.js"></script><script src="../../assets/scripts/tui-site.js" defer></script>
</head><body>
  <a class="skip-link" href="#main">Skip to content</a>${navigation("../../", "components")}
  <main id="main" class="component-doc-shell">
    ${sideNavigation(item.slug)}
    <article class="component-doc">
      <ol class="breadcrumb" aria-label="Breadcrumb"><li><a href="../../">Flyology TUI</a></li><li><a href="../">Components</a></li><li aria-current="page">${escapeHtml(item.title)}</li></ol>
      <header class="component-hero"><p class="eyebrow">${item.group}</p><h1>${escapeHtml(item.title)}</h1><p>${escapeHtml(item.summary)}</p></header>
      ${skinSwitcher(item)}
      <section><h2>When to use it</h2><p>${escapeHtml(item.use)}</p></section>
      <section><h2>State and ownership</h2><p>The <a href="../../api/${apiHref}"><code>${packageId}</code></a> package defines this component.</p><p>${escapeHtml(item.model)}</p><ul>${item.ownership.map((line) => `<li>${escapeHtml(line)}</li>`).join("")}</ul></section>
      <section><h2>Update and interaction</h2><p>${escapeHtml(item.interaction)}</p><p>${escapeHtml(item.keyboard)}</p></section>
      <section><h2>Minimal use</h2><figure class="code-panel"><figcaption>${escapeHtml(item.title)} update and render path</figcaption><button class="copy-button" type="button" data-copy>Copy</button><pre><code class="language-ada">${escapeHtml(item.code)}</code></pre></figure></section>
      <section><h2>Responsive and accessible behavior</h2><ul><li>Resize the component or create a fresh immutable presentation from the current layout snapshot.</li><li>Route captured mouse release to its owner even when the pointer leaves the original bounds.</li><li>Keep a visible glyph, label, border, or attribute cue when terminal color is reduced.</li></ul></section>
      <nav class="component-pager" aria-label="Adjacent components">${adjacentLinks(item)}</nav>
    </article>
  </main>${footer("../../")}
</body></html>`;
}

function adjacentLinks(item) {
  const index = components.findIndex((candidate) => candidate.slug === item.slug);
  const previous = components[(index + components.length - 1) % components.length];
  const next = components[(index + 1) % components.length];
  return `<a href="../${previous.slug}/"><span>Previous</span>${previous.title}</a><a href="../${next.slug}/"><span>Next</span>${next.title}</a>`;
}

function componentsIndex() {
  return `<!doctype html><html lang="en"><head>
    <meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="Every public Flyology TUI component, with usage guidance, API links, and generated previews in all skins.">
    <meta name="theme-color" content="#241b35"><title>Components · Flyology TUI</title>
    <link rel="canonical" href="https://tui.flyology.org/components/"><link rel="icon" href="../assets/brand/flyology-primary-icon.svg" type="image/svg+xml">
    <link rel="stylesheet" href="../assets/styles/site.css"><link rel="stylesheet" href="../assets/styles/tui.css">
    <script src="../assets/scripts/site.js"></script><script src="../assets/scripts/tui-site.js" defer></script>
  </head><body><a class="skip-link" href="#main">Skip to content</a>${navigation("../", "components")}
    <main id="main" class="page-shell component-index">
      <header class="doc-hero"><div><ol class="breadcrumb" aria-label="Breadcrumb"><li><a href="../">Flyology TUI</a></li><li aria-current="page">Components</li></ol><h1>Every bounded component.</h1></div><p class="doc-hero-copy">Each page explains ownership, update behavior, responsive geometry, keyboard and mouse parity, and the exact generated API entry. Four build-generated previews show the same component in every bundled skin.</p></header>
      <div class="component-filter"><label for="component-search">Filter components</label><input id="component-search" type="search" placeholder="Try editor, layout, table…" data-component-search><span data-component-count>${components.length} components</span></div>
      <div data-component-list>${groups.map((group) => `<section class="catalog-group" data-component-group><div class="catalog-group-heading"><p>${group}</p><span>${components.filter((item) => item.group === group).length}</span></div><ul>${components.filter((item) => item.group === group).map((item) => `<li data-component-item data-search="${escapeHtml(`${item.title} ${item.summary} ${item.group}`.toLowerCase())}"><a href="${item.slug}/"><span><strong>${item.title}</strong><small>${escapeHtml(item.summary)}</small></span><svg aria-hidden="true" viewBox="0 0 20 20" fill="none" stroke="currentColor"><path d="M4 10h11M11 6l4 4-4 4"/></svg></a></li>`).join("")}</ul></section>`).join("")}</div>
      <p class="component-empty" data-component-empty hidden>No component matches that filter.</p>
    </main>${footer("../")}</body></html>`;
}

await verifyCatalog();
const apiEntries = await readApiEntries();
const apiMap = new Map(apiEntries
  .filter((entry) => entry.kind === "Compilation unit")
  .map((entry) => [entry.qualifiedName, entry.href]));

const componentsRoot = join(siteRoot, "components");
await mkdir(componentsRoot, { recursive: true });
await writeFile(join(componentsRoot, "index.html"), componentsIndex());

for (const item of components) {
  const packageId = packageName(item);
  const apiHref = apiMap.get(packageId);
  if (!apiHref) throw new Error(`GNATdoc has no compilation unit for ${packageId}`);
  const pageRoot = join(componentsRoot, item.slug);
  const imageRoot = join(pageRoot, "images");
  await mkdir(imageRoot, { recursive: true });
  await writeFile(join(pageRoot, "index.html"), componentPage(item, apiHref));
  for (const skin of skins) {
    await writeFile(join(imageRoot, `${skin.id}.svg`), svgPreview(item, skin));
  }
}

console.log(`Generated ${components.length} component pages and ${components.length * skins.length} skin previews.`);
