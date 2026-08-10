import { createHash } from "node:crypto";
import { readdir, readFile, writeFile } from "node:fs/promises";
import { join, resolve } from "node:path";

const siteRoot = resolve(process.argv[2]);

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

const assets = ["site.css", "tui.css", "site.js", "tui-site.js", "ada-highlight.js"];
const versions = new Map();
for (const asset of assets) {
  const matches = (await filesBelow(join(siteRoot, "assets")))
    .filter((path) => path.endsWith(`/${asset}`));
  if (matches.length !== 1) throw new Error(`expected one ${asset}, found ${matches.length}`);
  const content = await readFile(matches[0]);
  versions.set(asset, createHash("sha256").update(content).digest("hex").slice(0, 10));
}

for (const file of (await filesBelow(siteRoot)).filter((path) => path.endsWith(".html"))) {
  let html = await readFile(file, "utf8");
  html = html.replaceAll('href=""', 'href="./"');
  for (const [asset, version] of versions) {
    html = html.replaceAll(`${asset}\"`, `${asset}?v=${version}\"`);
  }
  await writeFile(file, html);
}
