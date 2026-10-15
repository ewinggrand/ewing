import { mkdir, copyFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";

// Explicitly refresh the versioned downloads only when preparing a release.
// The normal environment setup writes generated files to ignored dist/ only.
const directory = new URL("../downloads/", import.meta.url);
await mkdir(directory, { recursive: true });
for (const name of ["wicklungsatelier.html", "wicklungsatelier-offline.zip"]) {
  await copyFile(new URL(`../dist/${name}`, import.meta.url), new URL(name, directory));
}
console.log(`Download-Dateien aktualisiert: ${fileURLToPath(directory)}`);
