import { readFile, writeFile, readdir } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { zipSync, strToU8 } from "fflate";

// Package the production bundle for direct file:// use without a web server.
const distDir = fileURLToPath(new URL("../dist/", import.meta.url));
let html = await readFile(resolve(distDir, "index.html"), "utf8");
const scripts = [...html.matchAll(/<script\b[^>]*\bsrc="([^"]+)"[^>]*><\/script>/g)];
const styles = [...html.matchAll(/<link\b[^>]*\brel="stylesheet"[^>]*\bhref="([^"]+)"[^>]*>/g)];
const assets = await readdir(resolve(distDir, "assets"));

if (scripts.length !== 1 || assets.filter((name) => name.endsWith(".js")).length !== 1) {
  throw new Error("Der Offline-Export benötigt genau ein vollständig gebündeltes JavaScript-Modul.");
}

function assetPath(reference) {
  const path = resolve(distDir, reference.replace(/^\//, ""));
  if (!path.startsWith(distDir)) throw new Error("Ungültiger Asset-Pfad im Produktionsbuild.");
  return path;
}

for (const [tag, src] of scripts) {
  const js = await readFile(assetPath(src), "utf8");
  if (/\bimport\s*\(/.test(js)) {
    throw new Error("Dynamische Imports müssen vor dem Offline-Export vollständig gebündelt werden.");
  }
  html = html.replace(tag, () => `<script type="module">${js.replace(/<\/script/gi, "<\\/script")}</script>`);
}

for (const [tag, href] of styles) {
  const css = await readFile(assetPath(href), "utf8");
  if (/@import\b|url\((?!["']?data:)/i.test(css)) {
    throw new Error("Der Offline-Export benötigt eingebettete CSS-Ressourcen.");
  }
  html = html.replace(tag, () => `<style>${css}</style>`);
}

const icon = await readFile(resolve(distDir, "favicon.svg"), "utf8");
html = html.replace(/<link\b[^>]*\brel="icon"[^>]*>/, () =>
  `<link rel="icon" type="image/svg+xml" href="data:image/svg+xml,${encodeURIComponent(icon)}" />`,
);

if (/<(?:script|link)\b[^>]*(?:src|href)="(?!data:)[^"]+"/.test(html)) {
  throw new Error("Der Offline-Export enthält noch eine externe Ressource.");
}

const output = resolve(distDir, "wicklungsatelier.html");
await writeFile(output, html);
console.log(`Offline-App erstellt: ${output} (${Math.round(Buffer.byteLength(html) / 1024)} KiB)`);

const instructions = `Wicklungsatelier

wicklungsatelier.html per Doppelklick im eigenen Browser öffnen.
Keine Installation und keine Internetverbindung erforderlich.

Q = Nutenzahl, p = Polpaarzahl.
Die automatische Auswahl optimiert innerhalb des dokumentierten 60-Grad-Zonenmodells.
`;
const zip = zipSync({
  "wicklungsatelier.html": strToU8(html),
  "LESEN.txt": strToU8(instructions),
}, { level: 9, mtime: new Date("2020-01-01T00:00:00Z") });
await writeFile(resolve(distDir, "wicklungsatelier-offline.zip"), zip);
console.log(`Offline-ZIP erstellt (${Math.round(zip.length / 1024)} KiB)`);
