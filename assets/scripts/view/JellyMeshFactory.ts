// Jelly Cube 3D — Procedural Rounded-Bevel 3D Mesh Factory (Cocos Creator 3.8.6)

import { Mesh, primitives, utils } from 'cc';

let cachedCoreMesh: Mesh | null = null;
let cachedStickerMesh: Mesh | null = null;
let cachedPlateMesh: Mesh | null = null;

function createRoundedBoxMesh(
    sx: number,
    sy: number,
    sz: number,
    roundness = 0.22,
    seg = 4,
): Mesh {
    const hx = sx / 2;
    const hy = sy / 2;
    const hz = sz / 2;
    const bevel = Math.min(hx, hy, hz) * roundness;
    const ix = Math.max(0.001, hx - bevel);
    const iy = Math.max(0.001, hy - bevel);
    const iz = Math.max(0.001, hz - bevel);

    const projectRounded = (px: number, py: number, pz: number) => {
        const cx = Math.max(-ix, Math.min(ix, px));
        const cy = Math.max(-iy, Math.min(iy, py));
        const cz = Math.max(-iz, Math.min(iz, pz));
        let dx = px - cx;
        let dy = py - cy;
        let dz = pz - cz;
        const len = Math.hypot(dx, dy, dz);
        if (len > 1e-5) {
            dx /= len;
            dy /= len;
            dz /= len;
            return {
                p: [cx + dx * bevel, cy + dy * bevel, cz + dz * bevel] as const,
                n: [dx, dy, dz] as const,
            };
        }
        const ax = Math.abs(px / hx);
        const ay = Math.abs(py / hy);
        const az = Math.abs(pz / hz);
        const n: readonly [number, number, number] =
            ax >= ay && ax >= az
                ? [Math.sign(px), 0, 0]
                : ay >= az
                  ? [0, Math.sign(py), 0]
                  : [0, 0, Math.sign(pz)];
        return { p: [px, py, pz] as const, n };
    };

    const faces = [
        { origin: [-hx, hy, hz], u: [sx, 0, 0], v: [0, 0, -sz] },
        { origin: [-hx, -hy, -hz], u: [sx, 0, 0], v: [0, 0, sz] },
        { origin: [-hx, -hy, hz], u: [sx, 0, 0], v: [0, sy, 0] },
        { origin: [hx, -hy, -hz], u: [-sx, 0, 0], v: [0, sy, 0] },
        { origin: [hx, -hy, hz], u: [0, 0, -sz], v: [0, sy, 0] },
        { origin: [-hx, -hy, -hz], u: [0, 0, sz], v: [0, sy, 0] },
    ];

    const positions: number[] = [];
    const normals: number[] = [];
    const uvs: number[] = [];
    const indices: number[] = [];
    let vertIndex = 0;

    for (const f of faces) {
        for (let j = 0; j < seg; j++) {
            const v0 = j / seg;
            const v1 = (j + 1) / seg;
            for (let i = 0; i < seg; i++) {
                const u0 = i / seg;
                const u1 = (i + 1) / seg;
                const sample = (uu: number, vv: number) => {
                    const x = f.origin[0] + f.u[0] * uu + f.v[0] * vv;
                    const y = f.origin[1] + f.u[1] * uu + f.v[1] * vv;
                    const z = f.origin[2] + f.u[2] * uu + f.v[2] * vv;
                    return { ...projectRounded(x, y, z), uv: [uu, 1 - vv] as const };
                };
                const a = sample(u0, v0);
                const b = sample(u1, v0);
                const c = sample(u1, v1);
                const d = sample(u0, v1);
                for (const v of [a, b, c, d]) {
                    positions.push(v.p[0], v.p[1], v.p[2]);
                    normals.push(v.n[0], v.n[1], v.n[2]);
                    uvs.push(v.uv[0], v.uv[1]);
                }
                indices.push(
                    vertIndex, vertIndex + 1, vertIndex + 2,
                    vertIndex, vertIndex + 2, vertIndex + 3,
                );
                vertIndex += 4;
            }
        }
    }

    return utils.MeshUtils.createMesh({ positions, normals, uvs, indices });
}

/** Inner translucent rounded jelly core for each cubelet. */
export function getCubieCoreMesh(): Mesh {
    if (!cachedCoreMesh) {
        cachedCoreMesh = createRoundedBoxMesh(0.92, 0.92, 0.92, 0.24, 4);
    }
    return cachedCoreMesh;
}

/** Exterior glossy rounded flavor pad mounted on sticker faces. */
export function getCubieStickerMesh(): Mesh {
    if (!cachedStickerMesh) {
        cachedStickerMesh = createRoundedBoxMesh(0.92, 0.92, 0.10, 0.16, 3);
    }
    return cachedStickerMesh;
}

/** Ceramic dessert plate beneath the jelly cube. */
export function getPlateMesh(): Mesh {
    if (!cachedPlateMesh) {
        cachedPlateMesh = utils.MeshUtils.createMesh(
            primitives.cylinder(2.6, 2.35, 0.24, {
                radialSegments: 48,
                heightSegments: 1,
                capped: true,
            }),
        );
    }
    return cachedPlateMesh;
}
