import { mkdir, readdir, readFile, writeFile } from "node:fs/promises";
import { execFileSync } from "node:child_process";
import { basename, join, resolve } from "node:path";
import { components, groups, skins } from "./component-catalog.mjs";

const projectRoot = resolve(new URL("..", import.meta.url).pathname);
const siteRoot = resolve(process.argv[2] || join(projectRoot, "build/site"));
const apiIndex = join(projectRoot, "docs/api/search-index.js");
const captureProgram = join(projectRoot, "examples/bin/component_examples");

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

function skinSwitcher(item) {
  const attrs = skins.map((skin) =>
    `data-src-${skin.id}="../../assets/captures/${item.slug}/${skin.id}.svg"`).join(" ");
  return `<div class="skin-preview" data-skin-preview>
    <div class="skin-preview-toolbar">
      <div><span class="eyebrow">Generated preview</span><strong data-skin-current>${skins[0].label}</strong></div>
      <div class="segmented-control" role="group" aria-label="Preview skin">
        ${skins.map((skin, index) => `<button type="button" data-skin-choice="${skin.id}" aria-pressed="${index === 0}">${skin.label}</button>`).join("")}
      </div>
    </div>
    <img src="../../assets/captures/${item.slug}/${skins[0].id}.svg" ${attrs} data-skin-image data-preview-name="${escapeHtml(item.title)}" alt="Dedicated ${escapeHtml(item.title)} example rendered in the ${skins[0].label} skin">
    <p class="preview-note">The site build compiles the dedicated Ada component example, constructs ${escapeHtml(item.title)} through its public API, and exports that exact styled surface. <a href="https://github.com/flyology-ada/flyology-tui/blob/main/examples/src/component_examples.adb">Read the capture source.</a></p>
  </div>`;
}

function integrationSteps(item) {
  if (item.integration) return item.integration;
  if (item.kind === "gradient") return [
    "Create the fixed-capacity gradient model and replace its strictly ordered color stops atomically.",
    "Apply the gradient to a caller-owned surface region with the selected direction, interpolation, and foreground or background mode.",
    "Place the modified surface in the current layout; terminal color-profile adaptation occurs during rendering."
  ];
  if (item.passive) return [
    "Create or update the caller-owned values that the renderer reads.",
    "Borrow the values and appearance required by the selected render function.",
    "Place the returned surface in the current layout. Do not route input to this component."
  ];
  if (item.container) return [
    "Create the container geometry from the current terminal size.",
    "Render caller-owned child surfaces into the regions published by the container.",
    "Route child events before container events, using the same geometry snapshot."
  ];
  return [
    "Create the bounded model and populate it with caller-owned data.",
    "Route the current keyboard or local mouse event through the component handler.",
    "Apply the typed result, then render from the updated model with the current appearance."
  ];
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
      ${item.interaction ? `<section><h2>${item.passive ? "Behavior" : "Input and updates"}</h2><p>${escapeHtml(item.interaction)}</p></section>` : ""}
      <section><h2>Integration sequence</h2><ol>${integrationSteps(item).map((step) => `<li>${escapeHtml(step)}</li>`).join("")}</ol><p>See the linked package reference for its exact declarations and contracts.</p></section>
      <section><h2>Responsive and accessible behavior</h2><ul><li>Use dimensions and regions from the current layout or presentation value.</li>${item.passive ? "" : "<li>When a component owns mouse capture, route its matching release even when the pointer leaves the original bounds.</li>"}<li>Retain a glyph, label, border, or text-attribute cue when the terminal reduces color.</li></ul></section>
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
    <script src="../assets/scripts/ada-highlight.js"></script><script src="../assets/scripts/site.js"></script><script src="../assets/scripts/tui-site.js" defer></script>
  </head><body><a class="skip-link" href="#main">Skip to content</a>${navigation("../", "components")}
    <main id="main" class="page-shell component-index">
      <header class="doc-hero"><div><ol class="breadcrumb" aria-label="Breadcrumb"><li><a href="../">Flyology TUI</a></li><li aria-current="page">Components</li></ol><h1>Every bounded component.</h1></div><p class="doc-hero-copy">Each page explains ownership, input, responsive geometry, and the exact generated API package. Four build-generated captures run a dedicated example of that component in every bundled skin.</p></header>
      <div class="component-filter"><label for="component-search">Filter components</label><input id="component-search" type="search" placeholder="Try editor, layout, table…" data-component-search><span role="status" aria-live="polite" data-component-count>${components.length} components</span></div>
      <div data-component-list>${groups.map((group) => `<section class="catalog-group" data-component-group><div class="catalog-group-heading"><p>${group}</p><span>${components.filter((item) => item.group === group).length}</span></div><ul>${components.filter((item) => item.group === group).map((item) => `<li data-component-item data-search="${escapeHtml(`${item.title} ${item.summary} ${item.group}`.toLowerCase())}"><a href="${item.slug}/"><span><strong>${item.title}</strong><small>${escapeHtml(item.summary)}</small></span><svg aria-hidden="true" viewBox="0 0 20 20" fill="none" stroke="currentColor"><path d="M4 10h11M11 6l4 4-4 4"/></svg></a></li>`).join("")}</ul></section>`).join("")}</div>
      <p class="component-empty" role="status" data-component-empty hidden>No component matches that filter.</p>
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

const captureRoot = join(siteRoot, "assets/captures");
for (const item of components) {
  const componentRoot = join(captureRoot, item.slug);
  const componentCaptures = [];
  await mkdir(componentRoot, { recursive: true });
  for (const skin of skins) {
    const output = join(componentRoot, `${skin.id}.svg`);
    execFileSync(captureProgram, [
      `--component=${item.slug}`,
      `--skin=${skin.id}`,
      `--output=${output}`
    ], { stdio: "inherit" });
    const capture = await readFile(output, "utf8");
    if (!capture.startsWith("<svg") ||
        !capture.includes("<rect") ||
        !capture.includes("<text")) {
      throw new Error(`invalid ${skin.id} Ada capture for ${item.slug}`);
    }
    componentCaptures.push(capture);
  }
  if (new Set(componentCaptures).size !== skins.length) {
    throw new Error(`skin captures are not distinct for ${item.slug}`);
  }
}

const charmWindow = await readFile(
  join(captureRoot, "windows/charm-default.svg"), "utf8");
const turboWindow = await readFile(
  join(captureRoot, "windows/turbo-vision.svg"), "utf8");
if (!charmWindow.includes("─") || !turboWindow.includes("═")) {
  throw new Error("window captures do not preserve skin-specific Unicode frame glyphs");
}

for (const item of components) {
  const packageId = packageName(item);
  const apiHref = apiMap.get(packageId);
  if (!apiHref) throw new Error(`GNATdoc has no compilation unit for ${packageId}`);
  const pageRoot = join(componentsRoot, item.slug);
  await mkdir(pageRoot, { recursive: true });
  await writeFile(join(pageRoot, "index.html"), componentPage(item, apiHref));
}

console.log(`Generated ${components.length} component pages and ${components.length * skins.length} dedicated Ada component captures.`);
