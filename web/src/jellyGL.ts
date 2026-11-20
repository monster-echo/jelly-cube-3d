// WebGL2 3D Jelly Renderer for browser playtest & playable preview
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
} from '../../assets/scripts/core/JellyEngine';
import { hexToRgbNormalized, JellyPatternKind, JellySkinDef } from '../../assets/scripts/core/JellySkins';

const CUBIE_STEP = 0.52;

const VS_SRC = `#version 300 es
precision highp float;
layout(location = 0) in vec3 a_pos;
layout(location = 1) in vec3 a_norm;
layout(location = 2) in vec2 a_uv;

uniform mat4 u_mvp;
uniform mat4 u_model;
uniform mat3 u_normalMat;
uniform vec4 u_squash;
uniform vec4 u_poke;
uniform vec4 u_uvRect;

out vec3 v_worldNorm;
out vec3 v_worldPos;
out vec2 v_uv;
out float v_pokeMask;

void main() {
  vec3 p = a_pos * u_squash.xyz;
  p.x += a_pos.y * u_squash.w * 0.08;
  p.z -= a_pos.y * u_squash.w * 0.06;

  v_pokeMask = 0.0;
  if (abs(u_poke.w) > 0.001) {
    vec3 dir = normalize(u_poke.xyz + vec3(0.0001));
    float align = max(0.0, dot(normalize(a_pos + vec3(0.0001)), dir));
    float dent = pow(align, 2.2) * u_poke.w;
    p -= dir * dent * 0.22;
    v_pokeMask = dent;
  }

  vec4 wp = u_model * vec4(p, 1.0);
  v_worldPos = wp.xyz;
  v_worldNorm = normalize(u_normalMat * a_norm);
  v_uv = u_uvRect.xy + a_uv * u_uvRect.zw;
  gl_Position = u_mvp * vec4(p, 1.0);
}`;

const FS_SRC = `#version 300 es
precision highp float;
in vec3 v_worldNorm;
in vec3 v_worldPos;
in vec2 v_uv;
in float v_pokeMask;

uniform vec3 u_camPos;
uniform vec4 u_color;
uniform vec4 u_jelly; // x: wrap, y: rimStrength, z: rimPower, w: shininess
uniform vec3 u_emissive;
uniform vec3 u_lightDir;
uniform vec3 u_rimTint;
uniform float u_time;
uniform float u_matMode; // 0: jelly, 1: plush, 2: liquid, 3: sand
uniform sampler2D u_tex;
uniform float u_useTex;

out vec4 fragColor;

float hash3(vec3 p) {
  p = fract(p * vec3(443.897, 441.423, 437.195));
  p += dot(p, p.yzx + 19.19);
  return fract((p.x + p.y) * p.z);
}

void main() {
  vec3 N = normalize(v_worldNorm);
  vec3 V = normalize(u_camPos - v_worldPos);

  // Liquid surface ripple perturbation
  if (u_matMode > 1.5 && u_matMode < 2.5) {
    float rx = sin(v_worldPos.y * 9.0 + u_time * 3.6) * 0.14;
    float ry = cos(v_worldPos.x * 9.0 - u_time * 3.1) * 0.14;
    N = normalize(N + vec3(rx, ry, 0.0));
  }

  vec3 L = normalize(u_lightDir);
  vec3 H = normalize(L + V);

  float wrap = u_jelly.x;
  float diff = max(0.0, (dot(N, L) + wrap) / (1.0 + wrap));
  float fill = max(0.0, (dot(N, normalize(vec3(-0.6, -0.4, 0.5))) + 0.5) / 1.5) * 0.14;

  float specScale = u_useTex > 0.5 ? 0.18 : 0.36;
  float specMain = pow(max(0.0, dot(N, H)), u_jelly.w) * specScale;
  float specBroad = pow(max(0.0, dot(N, H)), max(8.0, u_jelly.w * 0.22)) * (specScale * 0.20);
  float fresnel = pow(1.0 - max(0.0, dot(N, V)), u_jelly.z) * u_jelly.y * 0.30;
  float shimmer = 0.02 * sin(u_time * 2.2 + v_worldPos.x * 2.5 + v_worldPos.y * 2.5);

  vec3 base = u_color.rgb;
  if (u_useTex > 0.5) {
    vec4 tex = texture(u_tex, v_uv);
    base = mix(base, tex.rgb * mix(vec3(1.0), base * 0.96, 0.48), tex.a);
  }

  vec3 extraGlow = vec3(0.0);
  if (u_matMode > 0.5 && u_matMode < 1.5) {
    // Plush: soft fabric grain + warm velvet rim, no wet specular
    float fuzz = hash3(floor(v_worldPos * 64.0)) * 0.10 - 0.05;
    base += fuzz;
    specMain *= 0.05;
    specBroad *= 0.10;
  } else if (u_matMode > 1.5 && u_matMode < 2.5) {
    // Liquid: animated water caustics
    float caustic = pow(max(0.0, sin((v_worldPos.x + v_worldPos.y) * 7.5 + u_time * 2.8) * 0.5 + 0.5), 5.0);
    extraGlow += vec3(0.14, 0.22, 0.28) * caustic;
  } else if (u_matMode > 2.5) {
    // Sand: flowing quicksand bands + sparkling glitter grains
    vec3 sandPos = floor((v_worldPos + vec3(0.0, u_time * 0.12, 0.0)) * 42.0);
    float grain = hash3(sandPos);
    float sparkle = pow(grain, 16.0) * (0.5 + 0.5 * sin(u_time * 8.0 + grain * 40.0));
    base *= 0.92 + 0.12 * sin(v_worldPos.y * 14.0 + u_time * 1.6);
    extraGlow += vec3(0.85, 0.78, 0.62) * sparkle;
  }

  vec3 lit = base * (0.54 + diff * 0.44 + fill + shimmer)
           + vec3(1.0) * (specMain + specBroad)
           + mix(base, u_rimTint, 0.60) * fresnel
           + u_emissive * 0.5
           + extraGlow
           + vec3(0.14, 0.12, 0.18) * max(0.0, v_pokeMask);

  // Soft highlight knee above 0.85: keeps whites/colors crisp & bright without clipping
  vec3 over = max(vec3(0.0), lit - vec3(0.85));
  lit = min(lit, vec3(0.85)) + over / (1.0 + over * 1.6);

  fragColor = vec4(lit, u_color.a);
}`;

type Vec3 = [number, number, number];
type Mat4 = Float32Array;

function mat4Identity(): Mat4 {
    const m = new Float32Array(16);
    m[0] = m[5] = m[10] = m[15] = 1;
    return m;
}

function mat4Mul(a: Mat4, b: Mat4): Mat4 {
    const o = new Float32Array(16);
    for (let c = 0; c < 4; c++) {
        for (let r = 0; r < 4; r++) {
            o[c * 4 + r] =
                a[0 * 4 + r] * b[c * 4 + 0] +
                a[1 * 4 + r] * b[c * 4 + 1] +
                a[2 * 4 + r] * b[c * 4 + 2] +
                a[3 * 4 + r] * b[c * 4 + 3];
        }
    }
    return o;
}

function mat4Perspective(fovRad: number, aspect: number, near: number, far: number): Mat4 {
    const f = 1 / Math.tan(fovRad / 2);
    const o = new Float32Array(16);
    o[0] = f / aspect;
    o[5] = f;
    o[10] = (far + near) / (near - far);
    o[11] = -1;
    o[14] = (2 * far * near) / (near - far);
    return o;
}

function mat4LookAt(eye: Vec3, target: Vec3, up: Vec3): Mat4 {
    const zx = eye[0] - target[0];
    const zy = eye[1] - target[1];
    const zz = eye[2] - target[2];
    const zl = Math.hypot(zx, zy, zz) || 1;
    const z: Vec3 = [zx / zl, zy / zl, zz / zl];

    const xx = up[1] * z[2] - up[2] * z[1];
    const xy = up[2] * z[0] - up[0] * z[2];
    const xz = up[0] * z[1] - up[1] * z[0];
    const xl = Math.hypot(xx, xy, xz) || 1;
    const x: Vec3 = [xx / xl, xy / xl, xz / xl];

    const y: Vec3 = [
        z[1] * x[2] - z[2] * x[1],
        z[2] * x[0] - z[0] * x[2],
        z[0] * x[1] - z[1] * x[0],
    ];

    const o = mat4Identity();
    o[0] = x[0]; o[4] = x[1]; o[8] = x[2];
    o[1] = y[0]; o[5] = y[1]; o[9] = y[2];
    o[2] = z[0]; o[6] = z[1]; o[10] = z[2];
    o[12] = -(x[0] * eye[0] + x[1] * eye[1] + x[2] * eye[2]);
    o[13] = -(y[0] * eye[0] + y[1] * eye[1] + y[2] * eye[2]);
    o[14] = -(z[0] * eye[0] + z[1] * eye[1] + z[2] * eye[2]);
    return o;
}

function mat4AxisAngle(axis: number, rad: number): Mat4 {
    const c = Math.cos(rad);
    const s = Math.sin(rad);
    const m = mat4Identity();
    if (axis === 0) {
        m[5] = c; m[6] = s; m[9] = -s; m[10] = c;
    } else if (axis === 1) {
        m[0] = c; m[2] = -s; m[8] = s; m[10] = c;
    } else {
        m[0] = c; m[1] = s; m[4] = -s; m[5] = c;
    }
    return m;
}

function mat4Translate(x: number, y: number, z: number): Mat4 {
    const m = mat4Identity();
    m[12] = x; m[13] = y; m[14] = z;
    return m;
}

function mat3iToMat4(m3: Mat3i): Mat4 {
    const a = m3.m;
    const m = mat4Identity();
    m[0] = a[0]; m[4] = a[1]; m[8] = a[2];
    m[1] = a[3]; m[5] = a[4]; m[9] = a[5];
    m[2] = a[6]; m[6] = a[7]; m[10] = a[8];
    return m;
}

function buildBoxGeometry(
    sx: number,
    sy: number,
    sz: number,
    roundness = 0.22,
    seg = 4,
): { verts: Float32Array; count: number } {
    const hx = sx / 2, hy = sy / 2, hz = sz / 2;
    const minHalf = Math.min(hx, hy, hz);
    const bevel = minHalf * roundness;
    const ix = Math.max(0.001, hx - bevel);
    const iy = Math.max(0.001, hy - bevel);
    const iz = Math.max(0.001, hz - bevel);

    const projectRounded = (px: number, py: number, pz: number): { p: Vec3; n: Vec3 } => {
        const cx = Math.max(-ix, Math.min(ix, px));
        const cy = Math.max(-iy, Math.min(iy, py));
        const cz = Math.max(-iz, Math.min(iz, pz));
        let dx = px - cx, dy = py - cy, dz = pz - cz;
        const len = Math.hypot(dx, dy, dz);
        if (len > 1e-5) {
            dx /= len; dy /= len; dz /= len;
            return {
                p: [cx + dx * bevel, cy + dy * bevel, cz + dz * bevel],
                n: [dx, dy, dz],
            };
        }
        // Flat interior of face
        const ax = Math.abs(px / hx), ay = Math.abs(py / hy), az = Math.abs(pz / hz);
        const n: Vec3 = ax >= ay && ax >= az ? [Math.sign(px), 0, 0] : ay >= az ? [0, Math.sign(py), 0] : [0, 0, Math.sign(pz)];
        return { p: [px, py, pz], n };
    };

    const faces: Array<{ origin: Vec3; u: Vec3; v: Vec3 }> = [
        { origin: [-hx, hy, hz], u: [sx, 0, 0], v: [0, 0, -sz] },   // +Y
        { origin: [-hx, -hy, -hz], u: [sx, 0, 0], v: [0, 0, sz] },  // -Y
        { origin: [-hx, -hy, hz], u: [sx, 0, 0], v: [0, sy, 0] },   // +Z
        { origin: [hx, -hy, -hz], u: [-sx, 0, 0], v: [0, sy, 0] },  // -Z
        { origin: [hx, -hy, hz], u: [0, 0, -sz], v: [0, sy, 0] },   // +X
        { origin: [-hx, -hy, -hz], u: [0, 0, sz], v: [0, sy, 0] },  // -X
    ];

    const data: number[] = [];
    for (const f of faces) {
        for (let j = 0; j < seg; j++) {
            const v0 = j / seg, v1 = (j + 1) / seg;
            for (let i = 0; i < seg; i++) {
                const u0 = i / seg, u1 = (i + 1) / seg;
                const pt = (uu: number, vv: number) => {
                    const x = f.origin[0] + f.u[0] * uu + f.v[0] * vv;
                    const y = f.origin[1] + f.u[1] * uu + f.v[1] * vv;
                    const z = f.origin[2] + f.u[2] * uu + f.v[2] * vv;
                    return { ...projectRounded(x, y, z), uv: [uu, 1 - vv] as [number, number] };
                };
                const a = pt(u0, v0), b = pt(u1, v0), c = pt(u1, v1), d = pt(u0, v1);
                for (const vert of [a, b, c, a, c, d]) {
                    data.push(...vert.p, ...vert.n, ...vert.uv);
                }
            }
        }
    }
    return { verts: new Float32Array(data), count: faces.length * seg * seg * 6 };
}

function buildDiscGeometry(r: number, h: number, seg = 40): { verts: Float32Array; count: number } {
    const data: number[] = [];
    for (let i = 0; i < seg; i++) {
        const a0 = (i / seg) * Math.PI * 2;
        const a1 = ((i + 1) / seg) * Math.PI * 2;
        const x0 = Math.cos(a0) * r, z0 = Math.sin(a0) * r;
        const x1 = Math.cos(a1) * r, z1 = Math.sin(a1) * r;
        data.push(0, h / 2, 0, 0, 1, 0, 0.5, 0.5, x0, h / 2, z0, 0, 1, 0, 0, 0, x1, h / 2, z1, 0, 1, 0, 1, 0);
    }
    return { verts: new Float32Array(data), count: seg * 3 };
}

export interface WebHit {
    cubie: JellyCubelet;
    worldNormal: Vec3;
    worldPoint: Vec3;
}

export class JellyWebGLRenderer {
    private gl: WebGL2RenderingContext;
    private prog: WebGLProgram;
    private coreVao: WebGLVertexArrayObject;
    private coreCount: number;
    private plateVao: WebGLVertexArrayObject;
    private plateCount: number;
    private stickerVaos = new Map<number, { vao: WebGLVertexArrayObject; count: number }>();
    private patternTextures = new Map<JellyPatternKind, WebGLTexture>();
    private remoteTextures = new Map<string, WebGLTexture>();

    private cube: JellyCube | null = null;
    private skin!: JellySkinDef;

    yaw = 38;
    pitch = 28;
    distance = 9.5;
    targetYaw = 38;
    targetPitch = 28;
    targetDistance = 9.5;

    private turnSprings: Array<{ axis: number; coordinates: number[]; angleDeg: number; velocityDeg: number }> = [];
    private activeTurn: { axis: number; coordinate: number; angleDeg: number } | null = null;
    private hintAnim: { axis: number; coordinates: number[]; sign: number; elapsed: number; duration: number } | null = null;
    private lift = 0;
    private liftVel = 0;
    private squashY = 1;
    private squashVel = 0;
    private pokeTimer = 0;
    private pokeStrength = 0;
    private pokeDir: Vec3 = [0, 1, 0];

    private lastVp = mat4Identity();
    private lastCamPos: Vec3 = [5, 4, 7];
    private totalTime = 0;
    lightingMood: 'studio' | 'sunset' | 'neon' = 'studio';

    constructor(private canvas: HTMLCanvasElement, skin: JellySkinDef) {
        const gl = canvas.getContext('webgl2', { antialias: true, alpha: false });
        if (!gl) throw new Error('WebGL2 unavailable');
        this.gl = gl;
        this.skin = skin;

        const vs = this.compile(gl.VERTEX_SHADER, VS_SRC);
        const fs = this.compile(gl.FRAGMENT_SHADER, FS_SRC);
        const prog = gl.createProgram()!;
        gl.attachShader(prog, vs);
        gl.attachShader(prog, fs);
        gl.linkProgram(prog);
        this.prog = prog;

        const coreGeom = buildBoxGeometry(0.92, 0.92, 0.92, 0.24, 4);
        this.coreVao = this.makeVao(coreGeom);
        this.coreCount = coreGeom.count;
        const plate = buildDiscGeometry(2.6, 0.22);
        this.plateVao = this.makeVao(plate);
        this.plateCount = plate.count;

        const padConfigs: Array<[number, number, number, number, number, number, number]> = [
            [FACE_U, 0.92, 0.10, 0.92, 0, 0.46, 0],
            [FACE_D, 0.92, 0.10, 0.92, 0, -0.46, 0],
            [FACE_F, 0.92, 0.92, 0.10, 0, 0, 0.46],
            [FACE_B, 0.92, 0.92, 0.10, 0, 0, -0.46],
            [FACE_R, 0.10, 0.92, 0.92, 0.46, 0, 0],
            [FACE_L, 0.10, 0.92, 0.92, -0.46, 0, 0],
        ];
        for (const [face, sx, sy, sz, ox, oy, oz] of padConfigs) {
            const g = buildBoxGeometry(sx, sy, sz, 0.16, 3);
            for (let i = 0; i < g.verts.length; i += 8) {
                g.verts[i] += ox;
                g.verts[i + 1] += oy;
                g.verts[i + 2] += oz;
            }
            this.stickerVaos.set(face, { vao: this.makeVao(g), count: g.count });
        }

        gl.enable(gl.DEPTH_TEST);
        gl.enable(gl.BLEND);
        gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    }

    private compile(type: number, src: string): WebGLShader {
        const gl = this.gl;
        const s = gl.createShader(type)!;
        gl.shaderSource(s, src);
        gl.compileShader(s);
        if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) {
            throw new Error(gl.getShaderInfoLog(s) || 'Shader error');
        }
        return s;
    }

    private makeVao(geom: { verts: Float32Array; count: number }): WebGLVertexArrayObject {
        const gl = this.gl;
        const vao = gl.createVertexArray()!;
        gl.bindVertexArray(vao);
        const buf = gl.createBuffer()!;
        gl.bindBuffer(gl.ARRAY_BUFFER, buf);
        gl.bufferData(gl.ARRAY_BUFFER, geom.verts, gl.STATIC_DRAW);
        gl.enableVertexAttribArray(0);
        gl.vertexAttribPointer(0, 3, gl.FLOAT, false, 32, 0);
        gl.enableVertexAttribArray(1);
        gl.vertexAttribPointer(1, 3, gl.FLOAT, false, 32, 12);
        gl.enableVertexAttribArray(2);
        gl.vertexAttribPointer(2, 2, gl.FLOAT, false, 32, 24);
        gl.bindVertexArray(null);
        return vao;
    }

    private getRemoteTexture(url?: string): WebGLTexture | null {
        if (!url) return null;
        const cached = this.remoteTextures.get(url);
        if (cached) return cached;

        const gl = this.gl;
        const tex = gl.createTexture()!;
        gl.bindTexture(gl.TEXTURE_2D, tex);
        // 1x1 transparent placeholder while loading
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, new Uint8Array([255, 255, 255, 0]));
        this.remoteTextures.set(url, tex);

        const img = new Image();
        img.crossOrigin = 'anonymous';
        img.onload = () => {
            gl.bindTexture(gl.TEXTURE_2D, tex);
            gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, img);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        };
        img.src = url;
        return tex;
    }

    private getPatternTexture(pattern: JellyPatternKind): WebGLTexture | null {
        if (pattern === 'none') return null;
        const cached = this.patternTextures.get(pattern);
        if (cached) return cached;

        const c = document.createElement('canvas');
        c.width = 256;
        c.height = 256;
        const ctx = c.getContext('2d')!;
        ctx.clearRect(0, 0, 256, 256);

        // Soft glossy white sticker outline
        ctx.lineCap = 'round';
        ctx.lineJoin = 'round';

        if (pattern === 'ribbon_cat') {
            // Ears
            ctx.fillStyle = '#FFFFFF';
            ctx.beginPath();
            ctx.moveTo(64, 108); ctx.lineTo(54, 48); ctx.lineTo(106, 78); ctx.closePath(); ctx.fill();
            ctx.beginPath();
            ctx.moveTo(192, 108); ctx.lineTo(202, 48); ctx.lineTo(150, 78); ctx.closePath(); ctx.fill();
            // Head
            ctx.beginPath();
            ctx.ellipse(128, 138, 74, 58, 0, 0, Math.PI * 2);
            ctx.fill();
            // Pink bow on right ear
            ctx.fillStyle = '#FF4F8B';
            ctx.beginPath(); ctx.ellipse(164, 70, 20, 13, -0.3, 0, Math.PI * 2); ctx.fill();
            ctx.beginPath(); ctx.ellipse(192, 82, 20, 13, -0.3, 0, Math.PI * 2); ctx.fill();
            ctx.fillStyle = '#FF85AE';
            ctx.beginPath(); ctx.arc(178, 76, 9, 0, Math.PI * 2); ctx.fill();
            // Eyes & nose
            ctx.fillStyle = '#2E2235';
            ctx.beginPath(); ctx.ellipse(96, 136, 7, 9, 0, 0, Math.PI * 2); ctx.fill();
            ctx.beginPath(); ctx.ellipse(160, 136, 7, 9, 0, 0, Math.PI * 2); ctx.fill();
            ctx.fillStyle = '#FFD15C';
            ctx.beginPath(); ctx.ellipse(128, 150, 8, 6, 0, 0, Math.PI * 2); ctx.fill();
            // Whiskers
            ctx.strokeStyle = '#2E2235'; ctx.lineWidth = 4;
            for (const dy of [-10, 4, 18]) {
                ctx.beginPath(); ctx.moveTo(46, 144 + dy); ctx.lineTo(74, 146 + dy * 0.5); ctx.stroke();
                ctx.beginPath(); ctx.moveTo(210, 144 + dy); ctx.lineTo(182, 146 + dy * 0.5); ctx.stroke();
            }
        } else if (pattern === 'mochi_bunny') {
            ctx.fillStyle = '#FFFFFF';
            ctx.beginPath(); ctx.ellipse(98, 72, 18, 44, -0.15, 0, Math.PI * 2); ctx.fill();
            ctx.beginPath(); ctx.ellipse(158, 72, 18, 44, 0.15, 0, Math.PI * 2); ctx.fill();
            ctx.fillStyle = '#FFB5CE';
            ctx.beginPath(); ctx.ellipse(98, 74, 9, 28, -0.15, 0, Math.PI * 2); ctx.fill();
            ctx.beginPath(); ctx.ellipse(158, 74, 9, 28, 0.15, 0, Math.PI * 2); ctx.fill();
            ctx.fillStyle = '#FFFFFF';
            ctx.beginPath(); ctx.ellipse(128, 148, 68, 56, 0, 0, Math.PI * 2); ctx.fill();
            ctx.fillStyle = '#FF9EBE';
            ctx.beginPath(); ctx.ellipse(84, 156, 13, 8, 0, 0, Math.PI * 2); ctx.fill();
            ctx.beginPath(); ctx.ellipse(172, 156, 13, 8, 0, 0, Math.PI * 2); ctx.fill();
            ctx.fillStyle = '#362742';
            ctx.beginPath(); ctx.arc(102, 140, 7, 0, Math.PI * 2); ctx.fill();
            ctx.beginPath(); ctx.arc(154, 140, 7, 0, Math.PI * 2); ctx.fill();
        } else if (pattern === 'honey_bear') {
            ctx.fillStyle = '#A86B3E';
            ctx.beginPath(); ctx.arc(76, 86, 26, 0, Math.PI * 2); ctx.fill();
            ctx.beginPath(); ctx.arc(180, 86, 26, 0, Math.PI * 2); ctx.fill();
            ctx.fillStyle = '#C98A55';
            ctx.beginPath(); ctx.ellipse(128, 142, 72, 62, 0, 0, Math.PI * 2); ctx.fill();
            ctx.fillStyle = '#FFF2D6';
            ctx.beginPath(); ctx.ellipse(128, 156, 30, 22, 0, 0, Math.PI * 2); ctx.fill();
            ctx.fillStyle = '#2E1E14';
            ctx.beginPath(); ctx.arc(98, 130, 7, 0, Math.PI * 2); ctx.fill();
            ctx.beginPath(); ctx.arc(158, 130, 7, 0, Math.PI * 2); ctx.fill();
            ctx.beginPath(); ctx.ellipse(128, 148, 9, 6, 0, 0, Math.PI * 2); ctx.fill();
        } else if (pattern === 'boba_tea') {
            ctx.fillStyle = '#FFF6E8';
            ctx.beginPath();
            ctx.moveTo(82, 86); ctx.lineTo(174, 86); ctx.lineTo(160, 206); ctx.lineTo(96, 206); ctx.closePath(); ctx.fill();
            ctx.fillStyle = '#4B2E2B';
            ctx.fillRect(122, 34, 12, 52);
            for (const [bx, by] of [[108, 186], [128, 188], [148, 184], [118, 168], [140, 170]]) {
                ctx.beginPath(); ctx.arc(bx, by, 9, 0, Math.PI * 2); ctx.fill();
            }
            ctx.fillStyle = '#FF8FA3';
            ctx.beginPath(); ctx.arc(106, 130, 6, 0, Math.PI * 2); ctx.fill();
            ctx.beginPath(); ctx.arc(150, 130, 6, 0, Math.PI * 2); ctx.fill();
        } else if (pattern === 'shiba_paw') {
            ctx.fillStyle = '#FFFFFF';
            ctx.beginPath(); ctx.ellipse(128, 156, 46, 38, 0, 0, Math.PI * 2); ctx.fill();
            for (const [px, py] of [[78, 102], [110, 82], [146, 82], [178, 102]]) {
                ctx.beginPath(); ctx.ellipse(px, py, 16, 20, 0, 0, Math.PI * 2); ctx.fill();
            }
            ctx.fillStyle = '#FF9BB8';
            ctx.beginPath(); ctx.ellipse(128, 158, 28, 22, 0, 0, Math.PI * 2); ctx.fill();
        } else if (pattern === 'pixel_heart') {
            const grid = [
                '01100110',
                '11111111',
                '11111111',
                '11111111',
                '01111110',
                '00111100',
                '00011000',
            ];
            ctx.fillStyle = '#FFFFFF';
            const cell = 20;
            const ox = 48, oy = 58;
            grid.forEach((row, r) => {
                for (let col = 0; col < row.length; col++) {
                    if (row[col] === '1') ctx.fillRect(ox + col * cell, oy + r * cell, cell - 1, cell - 1);
                }
            });
        }

        const gl = this.gl;
        const tex = gl.createTexture()!;
        gl.bindTexture(gl.TEXTURE_2D, tex);
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, c);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        this.patternTextures.set(pattern, tex);
        return tex;
    }

    bindCube(cube: JellyCube): void {
        this.cube = cube;
        this.turnSprings = [];
        this.activeTurn = null;
        this.hintAnim = null;
        this.targetYaw = 38;
        this.targetPitch = 28;
        this.targetDistance = 4.6 + cube.size * 2.2;
    }

    applySkin(skin: JellySkinDef): void {
        this.skin = skin;
    }

    orbitBy(dx: number, dy: number): void {
        this.targetYaw -= dx * 0.35;
        this.targetPitch = Math.max(-72, Math.min(72, this.targetPitch + dy * 0.32));
    }

    setInteractiveTurn(axis: number, coordinate: number, angleDeg: number): void {
        this.activeTurn = { axis, coordinate, angleDeg };
    }

    clearInteractiveTurn(): void {
        this.activeTurn = null;
    }

    animateMove(move: JellyMove, residualDeg: number): void {
        this.hintAnim = null;
        this.turnSprings.push({
            axis: move.axis,
            coordinates: [...move.coordinates],
            angleDeg: residualDeg,
            velocityDeg: 0,
        });
    }

    /** Visually demonstrates the suggested slice rotation without altering cube state. */
    playHintMotion(move: JellyMove): void {
        this.hintAnim = {
            axis: move.axis,
            coordinates: [...move.coordinates],
            sign: move.quarterTurns >= 0 ? 1 : -1,
            elapsed: 0,
            duration: 1.5,
        };
    }

    triggerPoke(n: Vec3): void {
        this.pokeTimer = 0.55;
        this.pokeDir = [...n];
    }

    triggerDrop(): void {
        this.lift = 1.35;
        this.liftVel = 0;
        this.squashY = 1.08;
        this.squashVel = 0;
    }

    triggerSolveBounce(): void {
        this.lift = 0.55;
        this.liftVel = 2.6;
        this.squashY = 1.16;
        this.squashVel = -1.8;
    }

    worldToScreen(p: Vec3): [number, number] {
        const m = this.lastVp;
        const x = m[0] * p[0] + m[4] * p[1] + m[8] * p[2] + m[12];
        const y = m[1] * p[0] + m[5] * p[1] + m[9] * p[2] + m[13];
        const w = m[3] * p[0] + m[7] * p[1] + m[11] * p[2] + m[15];
        const rect = this.canvas.getBoundingClientRect();
        return [((x / w) * 0.5 + 0.5) * rect.width, ((1 - (y / w) * 0.5 - 0.5)) * rect.height];
    }

    pickCubelet(clientX: number, clientY: number): WebHit | null {
        if (!this.cube) return null;
        const rect = this.canvas.getBoundingClientRect();
        const nx = ((clientX - rect.left) / rect.width) * 2 - 1;
        const ny = 1 - ((clientY - rect.top) / rect.height) * 2;

        const aspect = rect.width / Math.max(1, rect.height);
        const eye = this.lastCamPos;
        const target: Vec3 = [0, -0.1, 0];
        const fwd = normalize3([target[0] - eye[0], target[1] - eye[1], target[2] - eye[2]]);
        const right = normalize3(cross3(fwd, [0, 1, 0]));
        const up = cross3(right, fwd);
        const tanHalf = Math.tan((42 * Math.PI) / 360);

        const dir = normalize3([
            fwd[0] + right[0] * nx * tanHalf * aspect + up[0] * ny * tanHalf,
            fwd[1] + right[1] * nx * tanHalf * aspect + up[1] * ny * tanHalf,
            fwd[2] + right[2] * nx * tanHalf * aspect + up[2] * ny * tanHalf,
        ]);

        let bestT = Infinity;
        let bestCubie: JellyCubelet | null = null;
        let bestN: Vec3 = [0, 1, 0];
        const half = 0.48;

        for (const c of this.cube.cubies) {
            const cx = c.pos.x * CUBIE_STEP;
            const cy = c.pos.y * CUBIE_STEP;
            const cz = c.pos.z * CUBIE_STEP;
            const t = rayAABB(eye, dir, [cx - half, cy - half, cz - half], [cx + half, cy + half, cz + half]);
            if (t !== null && t > 0 && t < bestT) {
                bestT = t;
                bestCubie = c;
                const hx = eye[0] + dir[0] * t - cx;
                const hy = eye[1] + dir[1] * t - cy;
                const hz = eye[2] + dir[2] * t - cz;
                const ax = Math.abs(hx), ay = Math.abs(hy), az = Math.abs(hz);
                if (ax >= ay && ax >= az) bestN = [Math.sign(hx), 0, 0];
                else if (ay >= ax && ay >= az) bestN = [0, Math.sign(hy), 0];
                else bestN = [0, 0, Math.sign(hz)];
            }
        }

        if (!bestCubie) return null;
        return {
            cubie: bestCubie,
            worldNormal: bestN,
            worldPoint: [eye[0] + dir[0] * bestT, eye[1] + dir[1] * bestT, eye[2] + dir[2] * bestT],
        };
    }

    render(dt: number): void {
        const gl = this.gl;
        const dpr = Math.min(2, window.devicePixelRatio || 1);
        const w = Math.floor(this.canvas.clientWidth * dpr);
        const h = Math.floor(this.canvas.clientHeight * dpr);
        if (this.canvas.width !== w || this.canvas.height !== h) {
            this.canvas.width = w;
            this.canvas.height = h;
        }
        gl.viewport(0, 0, w, h);

        const [br, bg, bb] =
            this.lightingMood === 'neon'
                ? [0.09, 0.07, 0.18]
                : this.lightingMood === 'sunset'
                  ? [1.0, 0.92, 0.88]
                  : hexToRgbNormalized(this.skin.backdropTop);
        gl.clearColor(br, bg, bb, 1);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
        if (!this.cube) return;

        const step = Math.min(dt, 0.033);
        this.totalTime += step;
        const camLerp = 1 - Math.exp(-14 * step);
        this.yaw += (this.targetYaw - this.yaw) * camLerp;
        this.pitch += (this.targetPitch - this.pitch) * camLerp;
        this.distance += (this.targetDistance - this.distance) * camLerp;

        const yr = (this.yaw * Math.PI) / 180;
        const pr = (this.pitch * Math.PI) / 180;
        const camPos: Vec3 = [
            this.distance * Math.cos(pr) * Math.sin(yr),
            this.distance * Math.sin(pr),
            this.distance * Math.cos(pr) * Math.cos(yr),
        ];
        this.lastCamPos = camPos;

        const proj = mat4Perspective((42 * Math.PI) / 180, w / Math.max(1, h), 0.5, 100);
        const view = mat4LookAt(camPos, [0, -0.1, 0], [0, 1, 0]);
        const vp = mat4Mul(proj, view);
        this.lastVp = vp;

        if (this.hintAnim) {
            this.hintAnim.elapsed += step;
            if (this.hintAnim.elapsed >= this.hintAnim.duration) {
                this.hintAnim = null;
            }
        }
        const hintAngleDeg = this.hintAnim
            ? Math.abs(Math.sin((this.hintAnim.elapsed / this.hintAnim.duration) * Math.PI * 2)) *
              42 *
              this.hintAnim.sign
            : 0;

        // Springs
        for (let i = this.turnSprings.length - 1; i >= 0; i--) {
            const s = this.turnSprings[i];
            const acc = -240 * s.angleDeg - 16 * s.velocityDeg;
            s.velocityDeg += acc * step;
            s.angleDeg += s.velocityDeg * step;
            if (Math.abs(s.angleDeg) < 0.15 && Math.abs(s.velocityDeg) < 1) {
                this.turnSprings.splice(i, 1);
            }
        }
        if (this.lift > 0 || Math.abs(this.liftVel) > 0.01) {
            this.liftVel -= 26 * step;
            this.lift += this.liftVel * step;
            if (this.lift <= 0) {
                this.lift = 0;
                if (this.liftVel < -1.2) {
                    this.squashVel = this.liftVel * 0.45;
                    this.liftVel = -this.liftVel * 0.28;
                } else this.liftVel = 0;
            }
        }
        const sqAcc = -190 * (this.squashY - 1) - 12 * this.squashVel;
        this.squashVel += sqAcc * step;
        this.squashY += this.squashVel * step;
        const squashXZ = 1 / Math.sqrt(Math.max(0.65, this.squashY));

        if (this.pokeTimer > 0) {
            this.pokeTimer = Math.max(0, this.pokeTimer - step);
            const t = 1 - this.pokeTimer / 0.55;
            this.pokeStrength = Math.cos(t * Math.PI * 3.5) * Math.exp(-t * 4.5);
        } else {
            this.pokeStrength = 0;
        }

        const wobble = this.turnSprings.length > 0 ? Math.max(-0.4, Math.min(0.4, this.turnSprings[0].velocityDeg * 0.0012)) : 0;

        gl.useProgram(this.prog);
        gl.uniform3fv(gl.getUniformLocation(this.prog, 'u_camPos'), camPos);
        gl.uniform1f(gl.getUniformLocation(this.prog, 'u_time'), this.totalTime);
        const modeMap = { jelly: 0, plush: 1, liquid: 2, sand: 3 } as const;
        gl.uniform1f(
            gl.getUniformLocation(this.prog, 'u_matMode'),
            modeMap[this.skin.material.mode ?? 'jelly'],
        );
        if (this.lightingMood === 'sunset') {
            gl.uniform3f(gl.getUniformLocation(this.prog, 'u_lightDir'), 0.75, 0.45, 0.48);
            gl.uniform3f(gl.getUniformLocation(this.prog, 'u_rimTint'), 1.0, 0.65, 0.45);
        } else if (this.lightingMood === 'neon') {
            gl.uniform3f(
                gl.getUniformLocation(this.prog, 'u_lightDir'),
                Math.sin(this.totalTime * 0.9) * 0.7,
                0.75,
                Math.cos(this.totalTime * 0.9) * 0.7,
            );
            gl.uniform3f(gl.getUniformLocation(this.prog, 'u_rimTint'), 0.45, 0.92, 1.0);
        } else {
            gl.uniform3f(gl.getUniformLocation(this.prog, 'u_lightDir'), 0.45, 0.80, 0.55);
            gl.uniform3f(gl.getUniformLocation(this.prog, 'u_rimTint'), 1.0, 1.0, 1.0);
        }
        gl.uniform4f(gl.getUniformLocation(this.prog, 'u_squash'), squashXZ, this.squashY, squashXZ, wobble);
        gl.uniform4f(gl.getUniformLocation(this.prog, 'u_poke'), this.pokeDir[0], this.pokeDir[1], this.pokeDir[2], this.pokeStrength);
        const m = this.skin.material;
        gl.uniform4f(gl.getUniformLocation(this.prog, 'u_jelly'), m.wrapLight, m.rimStrength, m.rimPower, m.shininess);
        gl.uniform3f(gl.getUniformLocation(this.prog, 'u_emissive'), m.emissive[0], m.emissive[1], m.emissive[2]);

        const uMvp = gl.getUniformLocation(this.prog, 'u_mvp');
        const uModel = gl.getUniformLocation(this.prog, 'u_model');
        const uNorm = gl.getUniformLocation(this.prog, 'u_normalMat');
        const uColor = gl.getUniformLocation(this.prog, 'u_color');
        const uUseTex = gl.getUniformLocation(this.prog, 'u_useTex');
        const uTex = gl.getUniformLocation(this.prog, 'u_tex');
        const uUvRect = gl.getUniformLocation(this.prog, 'u_uvRect');
        const singleTex =
            this.getRemoteTexture(this.skin.remoteTextureUrl) ??
            this.getPatternTexture(this.skin.pattern ?? 'none');
        const faceTexs = this.skin.faceTextureUrls?.map((url) => this.getRemoteTexture(url)) ?? null;
        const isJigsaw = Boolean(this.skin.wholeFaceJigsaw);
        const cubeSize = this.cube.size;
        const tileScale = 1 / cubeSize;

        const faceUvRect = (c: JellyCubelet, face: number): [number, number, number, number] => {
            if (!isJigsaw) return [0, 0, 1, 1];
            const maxC = cubeSize - 1;
            const normIdx = (val: number, invert = false): number => {
                const idx = Math.round((val + maxC) / 2);
                return invert ? cubeSize - 1 - idx : idx;
            };
            let col = 0;
            let row = 0;
            if (face === FACE_F) {
                col = normIdx(c.homePos.x);
                row = normIdx(c.homePos.y, true);
            } else if (face === FACE_B) {
                col = normIdx(c.homePos.x, true);
                row = normIdx(c.homePos.y, true);
            } else if (face === FACE_R) {
                col = normIdx(c.homePos.z, true);
                row = normIdx(c.homePos.y, true);
            } else if (face === FACE_L) {
                col = normIdx(c.homePos.z);
                row = normIdx(c.homePos.y, true);
            } else if (face === FACE_U) {
                col = normIdx(c.homePos.x);
                row = normIdx(c.homePos.z);
            } else {
                col = normIdx(c.homePos.x);
                row = normIdx(c.homePos.z, true);
            }
            return [col * tileScale, row * tileScale, tileScale, tileScale];
        };

        // Draw plate (scaled to cube size & tinted softly by backdrop)
        gl.uniform1f(uUseTex, 0.0);
        const [prR, prG, prB] = hexToRgbNormalized(this.skin.backdropBottom);
        const plateScale = this.cube.size / 3;
        const plateModel = mat4Translate(0, -(this.cube.size * 0.52 + 0.34), 0);
        plateModel[0] = plateScale;
        plateModel[10] = plateScale;
        gl.uniformMatrix4fv(uModel, false, plateModel);
        gl.uniformMatrix4fv(uMvp, false, mat4Mul(vp, plateModel));
        gl.uniformMatrix3fv(uNorm, false, new Float32Array([1, 0, 0, 0, 1, 0, 0, 0, 1]));
        gl.uniform4f(uColor, Math.min(1, prR + 0.08), Math.min(1, prG + 0.08), Math.min(1, prB + 0.10), 1.0);
        gl.bindVertexArray(this.plateVao);
        gl.drawArrays(gl.TRIANGLES, 0, this.plateCount);

        // Sort cubies back-to-front for clean translucent jelly blending
        const sorted = [...this.cube.cubies].sort((a, b) => {
            const da =
                (a.pos.x * CUBIE_STEP - camPos[0]) ** 2 +
                (a.pos.y * CUBIE_STEP - camPos[1]) ** 2 +
                (a.pos.z * CUBIE_STEP - camPos[2]) ** 2;
            const db =
                (b.pos.x * CUBIE_STEP - camPos[0]) ** 2 +
                (b.pos.y * CUBIE_STEP - camPos[1]) ** 2 +
                (b.pos.z * CUBIE_STEP - camPos[2]) ** 2;
            return db - da;
        });

        const drawCubie = (c: JellyCubelet) => {
            let model = mat4Mul(
                mat4Translate(c.pos.x * CUBIE_STEP, c.pos.y * CUBIE_STEP + this.lift, c.pos.z * CUBIE_STEP),
                mat3iToMat4(c.orientation),
            );
            for (const s of this.turnSprings) {
                if (s.coordinates.includes(c.pos.at(s.axis))) {
                    model = mat4Mul(mat4AxisAngle(s.axis, (s.angleDeg * Math.PI) / 180), model);
                }
            }
            if (this.activeTurn && c.pos.at(this.activeTurn.axis) === this.activeTurn.coordinate) {
                model = mat4Mul(mat4AxisAngle(this.activeTurn.axis, (this.activeTurn.angleDeg * Math.PI) / 180), model);
            }
            if (this.hintAnim && this.hintAnim.coordinates.includes(c.pos.at(this.hintAnim.axis))) {
                model = mat4Mul(mat4AxisAngle(this.hintAnim.axis, (hintAngleDeg * Math.PI) / 180), model);
            }

            gl.uniformMatrix4fv(uModel, false, model);
            gl.uniformMatrix4fv(uMvp, false, mat4Mul(vp, model));
            gl.uniformMatrix3fv(uNorm, false, new Float32Array([
                model[0], model[1], model[2],
                model[4], model[5], model[6],
                model[8], model[9], model[10],
            ]));

            gl.uniform1f(uUseTex, 0.0);
            gl.uniform4f(uUvRect, 0, 0, 1, 1);
            gl.uniform4f(uColor, 0.98, 0.94, 0.98, m.alpha * 0.45);
            gl.bindVertexArray(this.coreVao);
            gl.drawArrays(gl.TRIANGLES, 0, this.coreCount);

            for (const face of c.stickers) {
                const tex = (faceTexs ? faceTexs[face] : singleTex) ?? null;
                if (tex) {
                    gl.activeTexture(gl.TEXTURE0);
                    gl.bindTexture(gl.TEXTURE_2D, tex);
                    gl.uniform1i(uTex, 0);
                    gl.uniform1f(uUseTex, 1.0);
                    const [ux, uy, uw, uh] = faceUvRect(c, face);
                    gl.uniform4f(uUvRect, ux, uy, uw, uh);
                } else {
                    gl.uniform1f(uUseTex, 0.0);
                }
                const [r, g, b] = hexToRgbNormalized(this.skin.colors[face]);
                gl.uniform4f(uColor, r, g, b, m.alpha);
                const sv = this.stickerVaos.get(face)!;
                gl.bindVertexArray(sv.vao);
                gl.drawArrays(gl.TRIANGLES, 0, sv.count);
            }
        };

        for (const c of sorted) drawCubie(c);
    }
}

function normalize3(v: Vec3): Vec3 {
    const l = Math.hypot(v[0], v[1], v[2]) || 1;
    return [v[0] / l, v[1] / l, v[2] / l];
}

function cross3(a: Vec3, b: Vec3): Vec3 {
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
}

function rayAABB(o: Vec3, d: Vec3, min: Vec3, max: Vec3): number | null {
    let tmin = -Infinity;
    let tmax = Infinity;
    for (let i = 0; i < 3; i++) {
        const inv = 1 / (d[i] || 1e-8);
        let t1 = (min[i] - o[i]) * inv;
        let t2 = (max[i] - o[i]) * inv;
        if (t1 > t2) [t1, t2] = [t2, t1];
        tmin = Math.max(tmin, t1);
        tmax = Math.min(tmax, t2);
        if (tmin > tmax) return null;
    }
    return tmin >= 0 ? tmin : tmax >= 0 ? tmax : null;
}
