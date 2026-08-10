import { access, readdir, readFile, writeFile } from "node:fs/promises";
import { basename, join, resolve } from "node:path";

const root = resolve(process.argv[2]);
const files = (await readdir(root)).filter((name) => name.endsWith(".html"));
const anchors = new Map();

for (const name of files) {
  const html = await readFile(join(root, name), "utf8");
  for (const match of html.matchAll(/\sid=([0-9a-f]{64})(?:\s|>)/g)) {
    anchors.set(match[1], name);
  }
}

for (const name of files) {
  const path = join(root, name);
  let html = await readFile(path, "utf8");
  html = html.replace("<html class=main>",
    '<html lang="en" class=main><head><meta name="viewport" content="width=device-width, initial-scale=1"></head>');
  for (const match of [...html.matchAll(/href=([0-9a-f]{64})\.html/g)]) {
    try {
      await access(join(root, `${match[1]}.html`));
    } catch {
      const owner = anchors.get(match[1]);
      if (!owner) throw new Error(`${basename(path)} has unresolved GNATdoc target ${match[1]}`);
      html = html.replaceAll(`href=${match[1]}.html`, `href=${owner}#${match[1]}`);
    }
  }
  await writeFile(path, html);
}
