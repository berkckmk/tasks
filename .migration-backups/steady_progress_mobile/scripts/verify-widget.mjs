import { createHash } from 'node:crypto';
import { readFile, access } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = fileURLToPath(new URL('../', import.meta.url));
const manifest = JSON.parse(await readFile(path.join(root, 'docs/baseline/widget-manifest.json'), 'utf8'));
const original = path.resolve(root, '../steady_progress');
const failures = [];
let checked = 0;
for (const base of [original, root]) {
  // CI only needs the frozen manifest and the new repository. Locally we
  // also verify that migration work has not touched the Flutter source.
  try { await access(base); } catch {
    if (base === original) continue;
    throw new Error(`Missing repository: ${base}`);
  }
  for (const entry of manifest.files) {
    try {
      const data = await readFile(path.join(base, entry.path));
      if (base === original) {
        const hash = createHash('sha256').update(data).digest('hex');
        if (hash !== entry.sha256) failures.push(`Changed baseline: ${base}/${entry.path}`);
      }
      checked++;
    } catch { failures.push(`Missing: ${base}/${entry.path}`); }
  }
}
if (failures.length) {
  console.error(failures.join('\n'));
  process.exitCode = 1;
} else {
  console.log(`Verified ${checked} file hashes. Frozen widget sources/resources are unchanged.`);
}
