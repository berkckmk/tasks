import { readFile, readdir } from 'node:fs/promises';
import { extname, join, relative } from 'node:path';

const root = new URL('../src/', import.meta.url);
const themeRoot = new URL('../src/theme/', import.meta.url).pathname;
const findings = [];

async function visit(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      await visit(path);
      continue;
    }
    if (!['.ts', '.tsx'].includes(extname(path)) || path.startsWith(themeRoot)) continue;
    const lines = (await readFile(path, 'utf8')).split('\n');
    lines.forEach((line, index) => {
      if (/#[\dA-Fa-f]{3,8}\b/.test(line)) findings.push([path, index + 1, 'hardcoded color']);
      if (/fontSize\s*:\s*\d/.test(line)) findings.push([path, index + 1, 'hardcoded font size']);
      if (/borderRadius\s*:\s*\d/.test(line)) findings.push([path, index + 1, 'hardcoded radius']);
    });
  }
}

await visit(root.pathname);

if (findings.length) {
  for (const [path, line, reason] of findings) {
    console.error(`${relative(root.pathname, path)}:${line}: ${reason}`);
  }
  process.exitCode = 1;
} else {
  console.log('Design-system audit passed: no raw colors, font sizes, or radii outside src/theme.');
}
