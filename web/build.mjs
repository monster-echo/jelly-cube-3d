import * as esbuild from 'esbuild';
import { cp, mkdir, rm } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..');
const dist = path.join(root, 'dist', 'web');

await rm(dist, { recursive: true, force: true });
await mkdir(dist, { recursive: true });

await esbuild.build({
    entryPoints: [path.join(here, 'src', 'main.ts')],
    bundle: true,
    format: 'esm',
    target: ['es2020', 'safari14'],
    minify: true,
    outfile: path.join(dist, 'main.js'),
    logLevel: 'info',
});

await cp(path.join(here, 'index.html'), path.join(dist, 'index.html'));
await cp(path.join(here, 'style.css'), path.join(dist, 'style.css'));
await cp(path.join(here, 'assets', 'textures'), path.join(dist, 'textures'), { recursive: true });
console.log('Built dist/web');
