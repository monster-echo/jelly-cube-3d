import { createServer } from 'node:http';
import { mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { setTimeout as sleep } from 'node:timers/promises';

const ROOT = path.resolve(import.meta.dirname, '..');
const DIST = path.join(ROOT, 'dist', 'web');
const OUT = path.join(ROOT, 'tests', 'artifacts', 'playtest');
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

const MIME = {
    '.html': 'text/html; charset=utf-8',
    '.js': 'application/javascript; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
};

const server = createServer(async (req, res) => {
    const urlPath = (req.url || '/').split('?')[0];
    const rel = urlPath === '/' ? 'index.html' : urlPath.replace(/^\/+/, '');
    const file = path.join(DIST, rel);
    try {
        const data = await readFile(file);
        res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream' });
        res.end(data);
    } catch {
        res.writeHead(404);
        res.end('Not found');
    }
});

await new Promise((r) => server.listen(0, '127.0.0.1', r));
const port = server.address().port;
const baseUrl = `http://127.0.0.1:${port}/`;

await mkdir(OUT, { recursive: true });
const userDataDir = await mkdtemp(path.join(tmpdir(), 'jelly-chrome-'));
const chrome = spawn(CHROME, [
    '--headless=new',
    '--remote-debugging-port=0',
    `--user-data-dir=${userDataDir}`,
    '--window-size=430,860',
    '--use-gl=angle',
    '--use-angle=swiftshader',
    '--enable-webgl',
    '--ignore-gpu-blocklist',
    baseUrl,
]);

let wsUrl = '';
const deadline = Date.now() + 10000;
while (!wsUrl && Date.now() < deadline) {
    try {
        const raw = await readFile(path.join(userDataDir, 'DevToolsActivePort'), 'utf8');
        const [p] = raw.trim().split('\n');
        const pages = await (await fetch(`http://127.0.0.1:${p}/json/list`)).json();
        const page = pages.find((x) => x.type === 'page');
        if (page) wsUrl = page.webSocketDebuggerUrl;
    } catch {
        await sleep(150);
    }
}
if (!wsUrl) throw new Error('Chrome DevTools failed to start');

const ws = new WebSocket(wsUrl);
await new Promise((r) => ws.addEventListener('open', r));

let nextId = 1;
const pending = new Map();
const errors = [];
ws.addEventListener('message', (ev) => {
    const msg = JSON.parse(ev.data);
    if (msg.id && pending.has(msg.id)) {
        pending.get(msg.id)(msg);
        pending.delete(msg.id);
    } else if (msg.method === 'Runtime.exceptionThrown') {
        errors.push(JSON.stringify(msg.params));
    }
});

const send = (method, params = {}) =>
    new Promise((resolve) => {
        const id = nextId++;
        pending.set(id, resolve);
        ws.send(JSON.stringify({ id, method, params }));
    });

const evalJs = async (expression) => {
    const res = await send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
    return res.result?.result?.value;
};

const snap = async (name) => {
    await sleep(350);
    const res = await send('Page.captureScreenshot', { format: 'png' });
    const file = path.join(OUT, `${name}.png`);
    await writeFile(file, Buffer.from(res.result.data, 'base64'));
    console.log(`Saved ${name}.png`);
};

await send('Page.enable');
await send('Runtime.enable');
await send('Emulation.setDeviceMetricsOverride', { width: 430, height: 860, deviceScaleFactor: 2, mobile: true });
await sleep(800);

// 1. Level 1 (2x2 warmup)
await snap('01_level1_start');
await evalJs('window.__jellyPlaytest.solveOneStep()');
await sleep(450);
await snap('02_level1_win');

// 2. Level 11 with Japanese Healing Dessert AI texture (Ichigo Daifuku)
await evalJs('window.__jellyPlaytest.closeModal(); window.__jellyPlaytest.startLevel(11); window.__jellyPlaytest.unlockSkin("strawberry_daifuku");');
await sleep(500);
await snap('03_level11_ichigo_daifuku');

// 3. Skin Gallery modal & Calico Kitty preview
await evalJs('window.__jellyPlaytest.unlockSkin("calico_kitty");');
await sleep(500);
await snap('04_calico_kitty');

// 4. Daily Challenge with Nebula Night Glow skin
await evalJs('window.__jellyPlaytest.closeModal(); window.__jellyPlaytest.startDaily(); window.__jellyPlaytest.unlockSkin("nebula");');
await snap('05_daily_nebula');

// 5. Free Play 4x4 Classic
await evalJs('window.__jellyPlaytest.startFree(4); window.__jellyPlaytest.unlockSkin("classic");');
await snap('06_free_4x4');

console.log('Errors:', errors.length);
if (errors.length > 0) console.error(errors);

ws.close();
chrome.kill();
server.close();
await rm(userDataDir, { recursive: true, force: true }).catch(() => {});
