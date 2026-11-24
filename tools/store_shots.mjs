import { createServer } from 'node:http';
import { mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { setTimeout as sleep } from 'node:timers/promises';

// Store screenshots from the web build via headless Chrome + CDP.
//   node tools/store_shots.mjs   → tests/artifacts/store/*.png
// Two aspect ratios: iPhone 6.7" (1290×2796) and iPad Pro 12.9" (2048×2732).
// The game is pure canvas; interaction is CDP touch + drag on coordinates.

const ROOT = path.resolve(import.meta.dirname, '..');
const DIST = path.join(ROOT, 'dist', 'web');
const OUT = path.join(ROOT, 'tests', 'artifacts', 'store');
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

const MIME = {
    '.html': 'text/html; charset=utf-8',
    '.js': 'application/javascript',
    '.css': 'text/css',
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

const SESSIONS = [
    { name: 'iphone', cssW: 430, cssH: 932, scale: 3 }, // 1290×2796 (ASC 6.7")
    { name: 'ipad', cssW: 1024, cssH: 1366, scale: 2 }, // 2048×2732 (ASC 12.9")
    // Google Play phone screenshots require aspect between 1:2 and 2:1 —
    // 2796 tall is outside that, so capture a dedicated 1:2 set.
    { name: 'play_phone', cssW: 430, cssH: 860, scale: 3 }, // 1290×2580
];

await mkdir(OUT, { recursive: true });

for (const sess of SESSIONS) {
    const userDataDir = await mkdtemp(path.join(tmpdir(), `jelly-shots-${sess.name}-`));
    const chrome = spawn(CHROME, [
        '--headless=new',
        '--remote-debugging-port=0',
        `--user-data-dir=${userDataDir}`,
        `--window-size=${sess.cssW},${sess.cssH}`,
        '--use-gl=angle',
        '--use-angle=swiftshader',
        '--enable-webgl',
        '--ignore-gpu-blocklist',
        '--hide-scrollbars',
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
    ws.addEventListener('message', (ev) => {
        const msg = JSON.parse(ev.data);
        if (msg.id && pending.has(msg.id)) {
            pending.get(msg.id)(msg);
            pending.delete(msg.id);
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
        await sleep(400);
        const res = await send('Page.captureScreenshot', { format: 'png' });
        const file = path.join(OUT, `${sess.name}_${name}.png`);
        await writeFile(file, Buffer.from(res.result.data, 'base64'));
        console.log(`Saved ${sess.name}_${name}.png`);
    };

    // finger gesture across the canvas (Cocos touch)
    const touch = async (type, x, y) => {
        await send('Input.dispatchTouchEvent', {
            type,
            touchPoints: type === 'touchEnd' ? [] : [{ x, y, radiusX: 2, radiusY: 2, force: 0.6 }],
        });
    };

    const drag = async (x1, y1, x2, y2) => {
        await touch('touchStart', x1, y1);
        const steps = 8;
        for (let i = 1; i <= steps; i++) {
            await touch('touchMove', x1 + ((x2 - x1) * i) / steps, y1 + ((y2 - y1) * i) / steps);
            await sleep(30);
        }
        await touch('touchEnd', x2, y2);
    };

    await send('Page.enable');
    await send('Runtime.enable');
    await send('Emulation.setDeviceMetricsOverride', {
        width: sess.cssW,
        height: sess.cssH,
        deviceScaleFactor: sess.scale,
        mobile: true,
    });
    await sleep(1200);

    // wait for the scene to boot (renderer canvas exists and first frames drawn)
    for (let i = 0; i < 20; i++) {
        const ready = await evalJs('!!document.querySelector("canvas")');
        if (ready) break;
        await sleep(500);
    }
    await sleep(2500);

    const cx = sess.cssW / 2;
    const cy = sess.cssH * 0.42;

    // 1. fresh board, camera at default
    await snap('01_gameplay');

    // 2. orbit to a three-quarter view
    await drag(cx - sess.cssW * 0.35, cy, cx + sess.cssW * 0.3, cy + sess.cssH * 0.06);
    await snap('02_orbit');

    // 3. poke a cubelet (deform ripple)
    await drag(cx, cy, cx, cy);
    await snap('03_poke');

    // 4. another orbit from the other side
    await drag(cx + sess.cssW * 0.35, cy, cx - sess.cssW * 0.32, cy - sess.cssH * 0.05);
    await snap('04_overview');

    ws.close();
    chrome.kill();
    await rm(userDataDir, { recursive: true, force: true }).catch(() => {});
}

await new Promise((r) => server.close(r));
console.log('done');
