// محوّل تخزين مخزن Massive على القرص (الخادم): يوم = ملف data/days/YYYY-MM-DD.json
import { readFile, writeFile, mkdir, readdir, rm } from 'node:fs/promises';
import path from 'node:path';

export function diskStorage(dataDir) {
  const daysDir = path.join(dataDir, 'days');
  const ready = mkdir(daysDir, { recursive: true });
  const dayFile = d => path.join(daysDir, `${d}.json`);
  const metaFile = k => path.join(dataDir, `${k}.json`);
  return {
    async listDays() { await ready; return (await readdir(daysDir)).filter(f => f.endsWith('.json')).map(f => f.slice(0, -5)); },
    async readDay(d) { return JSON.parse(await readFile(dayFile(d), 'utf8')); },
    async writeDay(d, rows) { await ready; await writeFile(dayFile(d), JSON.stringify(rows)); },
    async removeDay(d) { await rm(dayFile(d), { force: true }); },
    async readMeta(k) { try { return JSON.parse(await readFile(metaFile(k), 'utf8')); } catch { return null; } },
    async writeMeta(k, v) { await ready; await writeFile(metaFile(k), JSON.stringify(v)); },
  };
}
