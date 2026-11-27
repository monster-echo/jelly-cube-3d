// Jelly Cube 3D — 3D Cubelet Scene View, Analytic Raycast, & Spring Physics

import {
    _decorator,
    Camera,
    Color,
    Component,
    EffectAsset,
    geometry,
    Material,
    Mat4,
    MeshRenderer,
    Node,
    Quat,
    resources,
    Texture2D,
    Vec3,
    Vec4,
} from 'cc';
import {
    FACE_B,
    FACE_D,
    FACE_F,
    FACE_L,
    FACE_R,
    FACE_U,
    JellyCube,
    JellyCubelet,
    JellyMove,
    Mat3i,
} from '../core/JellyEngine';
import { hexToRgbNormalized, JellySkinDef } from '../core/JellySkins';
import { getCubieCoreMesh, getCubieStickerMesh, getPlateMesh } from './JellyMeshFactory';

const { ccclass, property } = _decorator;

const CUBIE_STEP = 0.52; // Doubled lattice unit * 0.52 = 1.04 world spacing

export interface CubieHit {
    cubie: JellyCubelet;
    worldNormal: Vec3;
    worldPoint: Vec3;
}

interface TurnSpring {
    axis: number;
    coordinates: number[];
    angleDeg: number;
    velocityDeg: number;
}

const STICKER_LOCAL_OFFSET: Record<number, Vec3> = {
    [FACE_U]: new Vec3(0, 0.46, 0),
    [FACE_D]: new Vec3(0, -0.46, 0),
    [FACE_F]: new Vec3(0, 0, 0.46),
    [FACE_B]: new Vec3(0, 0, -0.46),
    [FACE_R]: new Vec3(0.46, 0, 0),
    [FACE_L]: new Vec3(-0.46, 0, 0),
};

const STICKER_LOCAL_EULER: Record<number, Vec3> = {
    [FACE_U]: new Vec3(-90, 0, 0),
    [FACE_D]: new Vec3(90, 0, 0),
    [FACE_F]: new Vec3(0, 0, 0),
    [FACE_B]: new Vec3(0, 180, 0),
    [FACE_R]: new Vec3(0, 90, 0),
    [FACE_L]: new Vec3(0, -90, 0),
};

function mat3iToQuat(m: Mat3i): Quat {
    const a = m.m;
    const mat4 = new Mat4(
        a[0], a[3], a[6], 0,
        a[1], a[4], a[7], 0,
        a[2], a[5], a[8], 0,
        0, 0, 0, 1,
    );
    const q = new Quat();
    Mat4.toRTS(mat4, q, null, null);
    return q;
}

function axisVec(axis: number): Vec3 {
    if (axis === 0) return new Vec3(1, 0, 0);
    if (axis === 1) return new Vec3(0, 1, 0);
    return new Vec3(0, 0, 1);
}

@ccclass('JellyCubeView')
export class JellyCubeView extends Component {
    @property(EffectAsset)
    jellyEffect: EffectAsset | null = null;

    @property(Camera)
    camera: Camera | null = null;

    private _cube: JellyCube | null = null;
    private _cubieNodes = new Map<number, Node>();
    private _plateNode: Node | null = null;

    private _coreMat: Material | null = null;
    private _flavorMats: Material[] = [];
    private _plateMat: Material | null = null;
    private _texCache = new Map<string, Texture2D>();

    private _turnSprings: TurnSpring[] = [];
    private _activeTurn: { axis: number; coordinate: number; angleDeg: number } | null = null;
    private _hintAnim: {
        axis: number;
        coordinates: number[];
        sign: number;
        elapsed: number;
        duration: number;
    } | null = null;

    // Drop / squash-and-stretch spring
    private _lift = 0;
    private _liftVel = 0;
    private _squashY = 1;
    private _squashVel = 0;

    // GPU poke dent
    private _pokeTimer = 0;
    private _pokeStrength = 0;
    private _pokeDir = new Vec4(0, 1, 0, 0);

    private _currentSkin: JellySkinDef | null = null;

    onLoad(): void {
        this._ensureMaterials();
        this._ensurePlate();
    }

    private _ensureMaterials(): void {
        if (this._coreMat) return;
        const makeMat = (r: number, g: number, b: number, a: number): Material => {
            const mat = new Material();
            if (this.jellyEffect) {
                mat.initialize({ effectAsset: this.jellyEffect, technique: 1 });
            } else {
                mat.initialize({ effectName: 'builtin-unlit' });
            }
            mat.setProperty('mainColor', new Vec4(r, g, b, a));
            return mat;
        };

        this._coreMat = makeMat(0.98, 0.94, 0.98, 0.35);
        this._flavorMats = Array.from({ length: 6 }, () => makeMat(1, 0.5, 0.6, 0.9));

        // builtin-standard is not packed unless an asset references it, so the
        // plate (and the no-effect fallback above) must use builtin-unlit.
        this._plateMat = new Material();
        if (this.jellyEffect) {
            this._plateMat.initialize({ effectAsset: this.jellyEffect, technique: 1 });
        } else {
            this._plateMat.initialize({ effectName: 'builtin-unlit' });
        }
        this._plateMat.setProperty('mainColor', new Vec4(0.988, 0.973, 0.98, 1));
    }

    private _ensurePlate(): void {
        if (this._plateNode) return;
        const plate = new Node('Plate');
        plate.parent = this.node;
        const mr = plate.addComponent(MeshRenderer);
        mr.mesh = getPlateMesh();
        // Never assign a pass-less material: it aborts bindCube and leaves the
        // whole cube unbuilt.
        if (this._plateMat && this._plateMat.passes.length > 0) mr.material = this._plateMat;
        plate.setPosition(0, -2.25, 0);
        this._plateNode = plate;
    }

    bindCube(cube: JellyCube): void {
        this._cube = cube;
        this._turnSprings.length = 0;
        this._activeTurn = null;

        for (const n of this._cubieNodes.values()) {
            n.destroy();
        }
        this._cubieNodes.clear();

        this._ensureMaterials();
        this._ensurePlate();

        const coreMesh = getCubieCoreMesh();
        const stickerMesh = getCubieStickerMesh();

        for (const cubie of cube.cubies) {
            const node = new Node(`Cubie_${cubie.id}`);
            node.parent = this.node;

            const coreMr = node.addComponent(MeshRenderer);
            coreMr.mesh = coreMesh;
            if (this._coreMat) coreMr.material = this._coreMat;

            for (const face of cubie.stickers) {
                const pad = new Node(`Sticker_${face}`);
                pad.parent = node;
                pad.setPosition(STICKER_LOCAL_OFFSET[face]);
                pad.setRotationFromEuler(STICKER_LOCAL_EULER[face]);
                const padMr = pad.addComponent(MeshRenderer);
                padMr.mesh = stickerMesh;
                const baseMat = this._flavorMats[face];
                // Per-sticker material instance allows independent jigsaw uvRect
                const instMat = new Material();
                instMat.copy(baseMat);
                padMr.material = instMat;
            }

            this._cubieNodes.set(cubie.id, node);
        }

        if (this._plateNode) {
            this._plateNode.setPosition(0, -(cube.size * 0.52 + 0.32), 0);
            const s = cube.size / 3;
            this._plateNode.setScale(s, 1, s);
        }

        if (this._currentSkin) {
            this.applySkin(this._currentSkin);
        }
        this.syncImmediate();
    }

    applySkin(skin: JellySkinDef): void {
        this._currentSkin = skin;
        this._ensureMaterials();
        const m = skin.material;
        const modeMap = { jelly: 0, plush: 1, liquid: 2, sand: 3 } as const;
        const matMode = modeMap[m.mode ?? 'jelly'];

        const applyTexToStickers = (tex: Texture2D | null) => {
            if (!this._cube) return;
            const size = this._cube.size;
            const maxC = size - 1;
            const tileScale = 1 / size;
            const normIdx = (val: number, invert = false): number => {
                const idx = Math.round((val + maxC) / 2);
                return invert ? size - 1 - idx : idx;
            };

            for (const cubie of this._cube.cubies) {
                const node = this._cubieNodes.get(cubie.id);
                if (!node) continue;
                for (const face of cubie.stickers) {
                    const pad = node.getChildByName(`Sticker_${face}`);
                    const mr = pad?.getComponent(MeshRenderer);
                    const mat = mr?.material;
                    if (!mat || !this.jellyEffect) continue;

                    const [r, g, b] = hexToRgbNormalized(skin.colors[face]);
                    mat.setProperty('mainColor', new Vec4(r, g, b, m.alpha));
                    mat.setProperty(
                        'emissiveColor',
                        new Vec4(m.emissive[0], m.emissive[1], m.emissive[2], 1),
                    );
                    mat.setProperty(
                        'jellyParams',
                        new Vec4(m.wrapLight, m.rimStrength, m.rimPower, m.shininess),
                    );
                    mat.setProperty('lightDir', new Vec4(0.45, 0.80, 0.55, matMode));

                    if (tex) {
                        mat.setProperty('mainTexture', tex);
                        mat.setProperty('useTexture', 1.0);
                        if (skin.wholeFaceJigsaw) {
                            let col = 0;
                            let row = 0;
                            if (face === FACE_F) {
                                col = normIdx(cubie.homePos.x);
                                row = normIdx(cubie.homePos.y, true);
                            } else if (face === FACE_B) {
                                col = normIdx(cubie.homePos.x, true);
                                row = normIdx(cubie.homePos.y, true);
                            } else if (face === FACE_R) {
                                col = normIdx(cubie.homePos.z, true);
                                row = normIdx(cubie.homePos.y, true);
                            } else if (face === FACE_L) {
                                col = normIdx(cubie.homePos.z);
                                row = normIdx(cubie.homePos.y, true);
                            } else if (face === FACE_U) {
                                col = normIdx(cubie.homePos.x);
                                row = normIdx(cubie.homePos.z);
                            } else {
                                col = normIdx(cubie.homePos.x);
                                row = normIdx(cubie.homePos.z, true);
                            }
                            mat.setProperty(
                                'uvRect',
                                new Vec4(col * tileScale, row * tileScale, tileScale, tileScale),
                            );
                        } else {
                            mat.setProperty('uvRect', new Vec4(0, 0, 1, 1));
                        }
                    } else {
                        mat.setProperty('useTexture', 0.0);
                        mat.setProperty('uvRect', new Vec4(0, 0, 1, 1));
                    }
                }
            }
        };

        for (let i = 0; i < 6; i++) {
            const [r, g, b] = hexToRgbNormalized(skin.colors[i]);
            const mat = this._flavorMats[i];
            if (this.jellyEffect) {
                mat.setProperty('mainColor', new Vec4(r, g, b, m.alpha));
                mat.setProperty(
                    'emissiveColor',
                    new Vec4(m.emissive[0], m.emissive[1], m.emissive[2], 1),
                );
                mat.setProperty(
                    'jellyParams',
                    new Vec4(m.wrapLight, m.rimStrength, m.rimPower, m.shininess),
                );
                mat.setProperty('lightDir', new Vec4(0.45, 0.80, 0.55, matMode));
            } else {
                mat.setProperty('albedo', new Color(r * 255, g * 255, b * 255, 255));
            }
        }

        if (skin.remoteTextureUrl) {
            const resPath = skin.remoteTextureUrl
                .replace('./textures/', 'textures/')
                .replace(/\.png$/i, '/texture');
            const cached = this._texCache.get(resPath);
            if (cached) {
                applyTexToStickers(cached);
            } else {
                applyTexToStickers(null);
                resources.load(resPath, Texture2D, (err, tex) => {
                    if (!err && tex) {
                        this._texCache.set(resPath, tex);
                        if (this._currentSkin?.id === skin.id) {
                            applyTexToStickers(tex);
                        }
                    }
                });
            }
        } else {
            applyTexToStickers(null);
        }

        if (this._coreMat && this.jellyEffect) {
            this._coreMat.setProperty('mainColor', new Vec4(0.99, 0.95, 1.0, m.alpha * 0.44));
            this._coreMat.setProperty(
                'jellyParams',
                new Vec4(m.wrapLight, m.rimStrength, m.rimPower, m.shininess),
            );
            this._coreMat.setProperty('lightDir', new Vec4(0.45, 0.80, 0.55, matMode));
        }

        const [br, bg, bb] = hexToRgbNormalized(skin.backdropTop);
        if (this._plateMat) {
            const [pr, pg, pb] = hexToRgbNormalized(skin.backdropBottom);
            const isDark = pr * 0.3 + pg * 0.59 + pb * 0.11 < 0.35;
            const plateColor = isDark
                ? new Vec4(pr * 1.25, pg * 1.25, pb * 1.25, 0.9)
                : new Vec4(pr * 0.96, pg * 0.93, pb * 1.0, 0.88);
            this._plateMat.setProperty('mainColor', plateColor);
        }

        if (this.camera) {
            this.camera.clearColor = new Color(br * 255, bg * 255, bb * 255, 255);
        }
    }

    /** Analytic ray-cubelet intersection for crisp 60/120fps touch picking. */
    pickCubelet(screenX: number, screenY: number): CubieHit | null {
        if (!this._cube || !this.camera) return null;
        const ray = this.camera.screenPointToRay(screenX, screenY);

        let bestT = Number.POSITIVE_INFINITY;
        let bestCubie: JellyCubelet | null = null;
        const bestNormal = new Vec3();
        const half = 0.48;

        for (const cubie of this._cube.cubies) {
            const cx = cubie.pos.x * CUBIE_STEP;
            const cy = cubie.pos.y * CUBIE_STEP;
            const cz = cubie.pos.z * CUBIE_STEP;

            const box = new geometry.AABB(cx, cy, cz, half, half, half);
            const t = geometry.intersect.rayAABB(ray, box);
            if (t > 0 && t < bestT) {
                bestT = t;
                bestCubie = cubie;
                const hitPt = new Vec3();
                Vec3.scaleAndAdd(hitPt, ray.o, ray.d, t);
                const dx = hitPt.x - cx;
                const dy = hitPt.y - cy;
                const dz = hitPt.z - cz;
                const ax = Math.abs(dx);
                const ay = Math.abs(dy);
                const az = Math.abs(dz);
                if (ax >= ay && ax >= az) bestNormal.set(Math.sign(dx), 0, 0);
                else if (ay >= ax && ay >= az) bestNormal.set(0, Math.sign(dy), 0);
                else bestNormal.set(0, 0, Math.sign(dz));
            }
        }

        if (!bestCubie) return null;
        const worldPoint = new Vec3();
        Vec3.scaleAndAdd(worldPoint, ray.o, ray.d, bestT);
        return { cubie: bestCubie, worldNormal: bestNormal, worldPoint };
    }

    setInteractiveTurn(axis: number, coordinate: number, angleDeg: number): void {
        this._activeTurn = { axis, coordinate, angleDeg };
    }

    clearInteractiveTurn(): void {
        this._activeTurn = null;
    }

    /** Adds an elastic spring residual after a discrete move is committed. */
    animateMove(move: JellyMove, residualAngleDeg: number, initialVelocityDeg = 0): void {
        this._hintAnim = null;
        this._turnSprings.push({
            axis: move.axis,
            coordinates: [...move.coordinates],
            angleDeg: residualAngleDeg,
            velocityDeg: initialVelocityDeg,
        });
    }

    /** Visually demonstrates the suggested slice rotation without altering cube state. */
    playHintMotion(move: JellyMove): void {
        this._hintAnim = {
            axis: move.axis,
            coordinates: [...move.coordinates],
            sign: move.quarterTurns >= 0 ? 1 : -1,
            elapsed: 0,
            duration: 1.5,
        };
    }

    triggerPoke(worldNormal: Vec3): void {
        this._pokeTimer = 0.55;
        this._pokeStrength = 1.0;
        this._pokeDir.set(worldNormal.x, worldNormal.y, worldNormal.z, 1.0);
    }

    triggerDrop(): void {
        this._lift = 1.35;
        this._liftVel = 0;
        this._squashY = 1.08;
        this._squashVel = 0;
    }

    triggerSolveBounce(): void {
        this._lift = 0.55;
        this._liftVel = 2.6;
        this._squashY = 1.24;
        this._squashVel = -3.0;
    }

    syncImmediate(): void {
        if (!this._cube) return;
        for (const cubie of this._cube.cubies) {
            const node = this._cubieNodes.get(cubie.id);
            if (!node) continue;
            node.setPosition(
                cubie.pos.x * CUBIE_STEP,
                cubie.pos.y * CUBIE_STEP,
                cubie.pos.z * CUBIE_STEP,
            );
            node.setRotation(mat3iToQuat(cubie.orientation));
        }
    }

    update(dt: number): void {
        if (!this._cube) return;
        const step = Math.min(dt, 0.033);

        if (this._hintAnim) {
            this._hintAnim.elapsed += step;
            if (this._hintAnim.elapsed >= this._hintAnim.duration) {
                this._hintAnim = null;
            }
        }
        const hintAngleDeg = this._hintAnim
            ? Math.abs(Math.sin((this._hintAnim.elapsed / this._hintAnim.duration) * Math.PI * 2)) *
              42 *
              this._hintAnim.sign
            : 0;

        // 1. Update slice turn springs (snappy, bouncy jelly settle)
        const stiffness = 280;
        const damping = 13.5;
        for (let i = this._turnSprings.length - 1; i >= 0; i--) {
            const s = this._turnSprings[i];
            const accel = -stiffness * s.angleDeg - damping * s.velocityDeg;
            s.velocityDeg += accel * step;
            s.angleDeg += s.velocityDeg * step;
            if (Math.abs(s.angleDeg) < 0.15 && Math.abs(s.velocityDeg) < 1.0) {
                this._turnSprings.splice(i, 1);
                // Subtle squash impulse when a slice snaps into place
                this._squashVel -= 0.9;
            }
        }

        // 2. Update drop & squash spring
        if (this._lift > 0 || Math.abs(this._liftVel) > 0.01) {
            this._liftVel -= 26 * step;
            this._lift += this._liftVel * step;
            if (this._lift <= 0) {
                this._lift = 0;
                if (this._liftVel < -1.2) {
                    this._squashVel = this._liftVel * 0.45;
                    this._liftVel = -this._liftVel * 0.28;
                } else {
                    this._liftVel = 0;
                }
            }
        }
        const sqAccel = -190 * (this._squashY - 1) - 12 * this._squashVel;
        this._squashVel += sqAccel * step;
        this._squashY += this._squashVel * step;
        const squashXZ = 1 / Math.sqrt(Math.max(0.65, this._squashY));

        // 3. Update GPU poke dent
        if (this._pokeTimer > 0) {
            this._pokeTimer = Math.max(0, this._pokeTimer - step);
            const t = 1 - this._pokeTimer / 0.55;
            this._pokeStrength = Math.cos(t * Math.PI * 3.5) * Math.exp(-t * 4.5);
        } else {
            this._pokeStrength = 0;
        }

        // Push shader uniforms to shared materials
        if (this.jellyEffect) {
            const wobble =
                this._turnSprings.length > 0
                    ? Math.max(-0.55, Math.min(0.55, this._turnSprings[0].velocityDeg * 0.0018))
                    : 0;
            const squashVec = new Vec4(squashXZ, this._squashY, squashXZ, wobble);
            const pokeVec = new Vec4(
                this._pokeDir.x,
                this._pokeDir.y,
                this._pokeDir.z,
                this._pokeStrength,
            );
            for (const mat of this._flavorMats) {
                mat.setProperty('squashVec', squashVec);
                mat.setProperty('pokeLocal', pokeVec);
            }
            if (this._coreMat) {
                this._coreMat.setProperty('squashVec', squashVec);
                this._coreMat.setProperty('pokeLocal', pokeVec);
            }
        }

        // 4. Update all cubie transforms
        const tmpPos = new Vec3();
        const tmpQuat = new Quat();
        const axisRot = new Quat();

        for (const cubie of this._cube.cubies) {
            const node = this._cubieNodes.get(cubie.id);
            if (!node) continue;

            tmpPos.set(
                cubie.pos.x * CUBIE_STEP,
                cubie.pos.y * CUBIE_STEP + this._lift,
                cubie.pos.z * CUBIE_STEP,
            );
            tmpQuat.set(mat3iToQuat(cubie.orientation));

            for (const s of this._turnSprings) {
                if (!s.coordinates.includes(cubie.pos.at(s.axis))) continue;
                const rad = (s.angleDeg * Math.PI) / 180;
                const av = axisVec(s.axis);
                Quat.fromAxisAngle(axisRot, av, rad);
                Vec3.transformQuat(tmpPos, tmpPos, axisRot);
                Quat.multiply(tmpQuat, axisRot, tmpQuat);
            }

            if (this._activeTurn && cubie.pos.at(this._activeTurn.axis) === this._activeTurn.coordinate) {
                const rad = (this._activeTurn.angleDeg * Math.PI) / 180;
                const av = axisVec(this._activeTurn.axis);
                Quat.fromAxisAngle(axisRot, av, rad);
                Vec3.transformQuat(tmpPos, tmpPos, axisRot);
                Quat.multiply(tmpQuat, axisRot, tmpQuat);
            }

            if (this._hintAnim && this._hintAnim.coordinates.includes(cubie.pos.at(this._hintAnim.axis))) {
                const rad = (hintAngleDeg * Math.PI) / 180;
                const av = axisVec(this._hintAnim.axis);
                Quat.fromAxisAngle(axisRot, av, rad);
                Vec3.transformQuat(tmpPos, tmpPos, axisRot);
                Quat.multiply(tmpQuat, axisRot, tmpQuat);
            }

            node.setPosition(tmpPos);
            node.setRotation(tmpQuat);
        }
    }
}
