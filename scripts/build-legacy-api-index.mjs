import { readFile, writeFile } from "node:fs/promises";
import { join, resolve } from "node:path";

const root = resolve(process.argv[2]);
const index = await readFile(join(root, "index.html"), "utf8");
const units = [];
const seen = new Set();
const compilationUnits = index.split("<h2 id=tagged-types>")[0];
const links = compilationUnits.matchAll(/<a\s+href=([^\s>#]+\.html)\s+target=document-content>([^<]+)<\/a>/g);

for (const match of links) {
  const href = match[1];
  const name = match[2];
  if (seen.has(name)) continue;
  seen.add(name);
  units.push({ name, qualifiedName: name, kind: "Compilation unit", href });

  const page = await readFile(join(root, href), "utf8");
  for (const entity of page.matchAll(/<h4\s+id=([^\s>]+)>([^<]+)<\/h4>/g)) {
    const entityName = entity[2].replaceAll("&quot;", '"');
    units.push({
      name: entityName,
      qualifiedName: `${name}.${entityName}`,
      kind: "API entity",
      href: `${href}#${entity[1]}`,
    });
  }
}

if (seen.size === 0) throw new Error("GNATdoc index contains no compilation units");
units.sort((left, right) => left.qualifiedName.localeCompare(right.qualifiedName));
await writeFile(join(root, "search-index.js"),
  `window.FlyologyApiSearch = ${JSON.stringify(units)};\n`);
console.log(`GNATdoc compatibility index generated: ${units.length} names from ${seen.size} units.`);
