import { readdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join, relative, resolve, sep } from "node:path";

const projectRoot = resolve(new URL("..", import.meta.url).pathname);
const siteRoot = resolve(process.argv[2] || join(projectRoot, "build/site"));
const indexPath = join(projectRoot, "docs/api/search-index.js");

async function filesBelow(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const results = [];
  for (const entry of entries) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) results.push(...await filesBelow(path));
    else results.push(path);
  }
  return results;
}

const raw = await readFile(indexPath, "utf8");
const prefix = "window.FlyologyApiSearch = ";
if (!raw.startsWith(prefix) || !raw.trimEnd().endsWith(";")) {
  throw new Error("unexpected GNATdoc search-index.js format");
}

const entries = JSON.parse(raw.slice(prefix.length).trim().replace(/;$/, ""));
const targets = new Map();
for (const entry of entries) {
  const previous = targets.get(entry.qualifiedName);
  if (!previous || entry.kind === "Compilation unit") {
    targets.set(entry.qualifiedName, entry.href);
  }
}

for (const file of (await filesBelow(siteRoot)).filter((path) => path.endsWith(".html"))) {
  let html = await readFile(file, "utf8");
  html = html.replace(/<a\s+data-api="([^"]+)"([^>]*)>/g, (_, name, rest) => {
    const target = targets.get(name);
    if (!target) throw new Error(`unresolved GNATdoc entity ${name} in ${file}`);
    let href = relative(dirname(file), join(siteRoot, "api", target));
    href = href.split(sep).join("/");
    return `<a href="${href}"${rest}>`;
  });
  if (html.includes("data-api=")) {
    throw new Error(`unresolved data-api attribute in ${file}`);
  }
  await writeFile(file, html);
}
