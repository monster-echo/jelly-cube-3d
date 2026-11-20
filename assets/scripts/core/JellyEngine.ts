// Jelly Cube 3D — discrete, drift-free 3D twisty puzzle engine.
// Integer lattice coordinates use doubled units:
//   2x2 -> {-1, 1}, 3x3 -> {-2, 0, 2}, 4x4 -> {-3, -1, 1, 3}.
// Every position and orientation coefficient is an integer, so rotations never
// accumulate floating-point drift.

export const FACE_U = 0;
export const FACE_D = 1;
export const FACE_F = 2;
export const FACE_B = 3;
export const FACE_R = 4;
export const FACE_L = 5;

export const FACE_NAMES = ['U', 'D', 'F', 'B', 'R', 'L'] as const;

export class Int3 {
    constructor(public readonly x: number, public readonly y: number, public readonly z: number) {}

    at(axis: number): number {
        return axis === 0 ? this.x : axis === 1 ? this.y : this.z;
    }

    add(o: Int3): Int3 {
        return new Int3(this.x + o.x, this.y + o.y, this.z + o.z);
    }

    equals(o: Int3): boolean {
        return this.x === o.x && this.y === o.y && this.z === o.z;
    }

    toString(): string {
        return `(${this.x},${this.y},${this.z})`;
    }
}

export const FACE_NORMALS: readonly Int3[] = [
    new Int3(0, 1, 0),  // U
    new Int3(0, -1, 0), // D
    new Int3(0, 0, 1),  // F
    new Int3(0, 0, -1), // B
    new Int3(1, 0, 0),  // R
    new Int3(-1, 0, 0), // L
];

/** Row-major 3x3 integer orthogonal matrix. */
export class Mat3i {
    static readonly IDENTITY = new Mat3i([1, 0, 0, 0, 1, 0, 0, 0, 1]);

    constructor(public readonly m: readonly number[]) {}

    apply(v: Int3): Int3 {
        const m = this.m;
        return new Int3(
            m[0] * v.x + m[1] * v.y + m[2] * v.z,
            m[3] * v.x + m[4] * v.y + m[5] * v.z,
            m[6] * v.x + m[7] * v.y + m[8] * v.z,
        );
    }

    mul(o: Mat3i): Mat3i {
        const out = new Array<number>(9).fill(0);
        for (let r = 0; r < 3; r++) {
            for (let c = 0; c < 3; c++) {
                let s = 0;
                for (let k = 0; k < 3; k++) {
                    s += this.m[r * 3 + k] * o.m[k * 3 + c];
                }
                out[r * 3 + c] = s;
            }
        }
        return new Mat3i(out);
    }

    transpose(): Mat3i {
        const m = this.m;
        return new Mat3i([m[0], m[3], m[6], m[1], m[4], m[7], m[2], m[5], m[8]]);
    }

    get determinant(): number {
        const m = this.m;
        return (
            m[0] * (m[4] * m[8] - m[5] * m[7]) -
            m[1] * (m[3] * m[8] - m[5] * m[6]) +
            m[2] * (m[3] * m[7] - m[4] * m[6])
        );
    }

    get isOrthogonal(): boolean {
        const p = this.mul(this.transpose());
        for (let i = 0; i < 9; i++) {
            const want = i % 4 === 0 ? 1 : 0;
            if (p.m[i] !== want) return false;
        }
        return this.determinant === 1;
    }
}

export function rotationMatrix(axis: number, quarterTurns: number): Mat3i {
    const q = ((quarterTurns % 4) + 4) % 4;
    switch (q) {
        case 0:
            return Mat3i.IDENTITY;
        case 1:
            if (axis === 0) return new Mat3i([1, 0, 0, 0, 0, -1, 0, 1, 0]);
            if (axis === 1) return new Mat3i([0, 0, 1, 0, 1, 0, -1, 0, 0]);
            return new Mat3i([0, -1, 0, 1, 0, 0, 0, 0, 1]);
        case 2:
            if (axis === 0) return new Mat3i([1, 0, 0, 0, -1, 0, 0, 0, -1]);
            if (axis === 1) return new Mat3i([-1, 0, 0, 0, 1, 0, 0, 0, -1]);
            return new Mat3i([-1, 0, 0, 0, -1, 0, 0, 0, 1]);
        default:
            if (axis === 0) return new Mat3i([1, 0, 0, 0, 0, 1, 0, -1, 0]);
            if (axis === 1) return new Mat3i([0, 0, -1, 0, 1, 0, 1, 0, 0]);
            return new Mat3i([0, 1, 0, -1, 0, 0, 0, 0, 1]);
    }
}

export interface JellyCubelet {
    id: number;
    pos: Int3;
    homePos: Int3;
    orientation: Mat3i;
    /** Local face indices (0..5) that carry an exterior flavor sticker. */
    stickers: Set<number>;
}

export interface JellyMove {
    axis: number;
    coordinates: number[];
    quarterTurns: number;
    notation?: string;
}

export function invertMove(move: JellyMove): JellyMove {
    return {
        axis: move.axis,
        coordinates: [...move.coordinates],
        quarterTurns: -move.quarterTurns,
        notation: move.notation ? `${move.notation}'` : undefined,
    };
}

export function layerCoordinatesForSize(size: number): number[] {
    const coords: number[] = [];
    for (let i = 0; i < size; i++) {
        coords.push(-(size - 1) + i * 2);
    }
    return coords;
}

export function createSeededRng(seed: number): () => number {
    let s = seed >>> 0;
    if (s === 0) s = 0x6d2b79f5;
    return () => {
        s = (s + 0x6d2b79f5) | 0;
        let t = Math.imul(s ^ (s >>> 15), 1 | s);
        t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
}

export type PatternGoal = 'solved' | 'checkerboard' | 'cross' | 'donut';

export class JellyCube {
    readonly size: number;
    readonly cubies: JellyCubelet[] = [];
    /** Full move history from solved state (scramble + player moves) for smart Hint. */
    private _solutionStack: JellyMove[] = [];
    /** Player-only move history for Undo. */
    private _undoStack: JellyMove[] = [];

    constructor(size = 3) {
        if (size < 2 || size > 10) {
            throw new Error(`Unsupported cube size: ${size}`);
        }
        this.size = size;
        this.reset();
    }

    reset(): void {
        this.cubies.length = 0;
        this._solutionStack.length = 0;
        this._undoStack.length = 0;

        const coords = layerCoordinatesForSize(this.size);
        const maxCoord = this.size - 1;
        let id = 0;

        for (const y of coords) {
            for (const x of coords) {
                for (const z of coords) {
                    const isInterior =
                        Math.abs(x) < maxCoord && Math.abs(y) < maxCoord && Math.abs(z) < maxCoord;
                    if (isInterior) continue;

                    const stickers = new Set<number>();
                    if (y === maxCoord) stickers.add(FACE_U);
                    if (y === -maxCoord) stickers.add(FACE_D);
                    if (z === maxCoord) stickers.add(FACE_F);
                    if (z === -maxCoord) stickers.add(FACE_B);
                    if (x === maxCoord) stickers.add(FACE_R);
                    if (x === -maxCoord) stickers.add(FACE_L);

                    this.cubies.push({
                        id: id++,
                        pos: new Int3(x, y, z),
                        homePos: new Int3(x, y, z),
                        orientation: Mat3i.IDENTITY,
                        stickers,
                    });
                }
            }
        }
    }

    get playerMoveCount(): number {
        return this._undoStack.length;
    }

    getPlayerMoves(): JellyMove[] {
        return this._undoStack.map((m) => ({
            axis: m.axis,
            coordinates: [...m.coordinates],
            quarterTurns: m.quarterTurns,
            notation: m.notation,
        }));
    }

    get canUndo(): boolean {
        return this._undoStack.length > 0;
    }

    /** Apply a move; if recordPlayer is true it counts toward player moves & undo. */
    applyMove(move: JellyMove, recordPlayer = true): void {
        const q = ((move.quarterTurns % 4) + 4) % 4;
        if (q === 0) return;

        const rot = rotationMatrix(move.axis, q);
        const coordSet = new Set(move.coordinates);

        for (const cubie of this.cubies) {
            if (!coordSet.has(cubie.pos.at(move.axis))) continue;
            cubie.pos = rot.apply(cubie.pos);
            cubie.orientation = rot.mul(cubie.orientation);
        }

        const normalized: JellyMove = {
            axis: move.axis,
            coordinates: [...move.coordinates],
            quarterTurns: q === 3 ? -1 : q,
            notation: move.notation,
        };

        this._pushToSolutionStack(normalized);
        if (recordPlayer) {
            this._undoStack.push(normalized);
        }
    }

    private _pushToSolutionStack(move: JellyMove): void {
        const top = this._solutionStack[this._solutionStack.length - 1];
        if (
            top &&
            top.axis === move.axis &&
            top.coordinates.length === move.coordinates.length &&
            top.coordinates.every((c, i) => c === move.coordinates[i])
        ) {
            const combined = (((top.quarterTurns + move.quarterTurns) % 4) + 4) % 4;
            this._solutionStack.pop();
            if (combined !== 0) {
                this._solutionStack.push({
                    axis: move.axis,
                    coordinates: [...move.coordinates],
                    quarterTurns: combined === 3 ? -1 : combined,
                    notation: move.notation,
                });
            }
            return;
        }
        this._solutionStack.push(move);
    }

    undo(): JellyMove | null {
        const last = this._undoStack.pop();
        if (!last) return null;
        const inv = invertMove(last);
        this.applyMove(inv, false);
        return inv;
    }

    /** Returns the next inverse move toward the solved state. */
    hintNextMove(): JellyMove | null {
        if (this._solutionStack.length === 0) return null;
        const top = this._solutionStack[this._solutionStack.length - 1];
        return invertMove(top);
    }

    /** Generates a clean, non-cancelling scramble sequence and applies it. */
    scramble(steps: number, rng: () => number = Math.random): JellyMove[] {
        const coords = layerCoordinatesForSize(this.size);
        const moves: JellyMove[] = [];
        let lastAxis = -1;
        let lastCoord = Number.NaN;

        for (let i = 0; i < steps; i++) {
            let axis = Math.floor(rng() * 3);
            let coord = coords[Math.floor(rng() * coords.length)];
            // Avoid immediately undoing or repeating the exact same slice.
            while (axis === lastAxis && coord === lastCoord) {
                axis = Math.floor(rng() * 3);
                coord = coords[Math.floor(rng() * coords.length)];
            }
            const quarterTurns = rng() < 0.5 ? 1 : -1;
            const move: JellyMove = { axis, coordinates: [coord], quarterTurns };
            this.applyMove(move, false);
            moves.push(move);
            lastAxis = axis;
            lastCoord = coord;
        }
        return moves;
    }

    /** Apply a fixed preset sequence (for curated endgame levels). */
    applyPresetScramble(moves: readonly JellyMove[]): void {
        this.reset();
        for (const m of moves) {
            this.applyMove(m, false);
        }
    }

    /** Marks the current state as the target base for hints (used by pattern levels). */
    markGoalBase(): void {
        this._solutionStack.length = 0;
        this._undoStack.length = 0;
    }

    /** World-space flavor index on each exterior face of a cubie. */
    getWorldFaceFlavors(cubie: JellyCubelet): Array<{ worldFace: number; flavor: number }> {
        const result: Array<{ worldFace: number; flavor: number }> = [];
        for (const localFace of cubie.stickers) {
            const worldNormal = cubie.orientation.apply(FACE_NORMALS[localFace]);
            const worldFace = FACE_NORMALS.findIndex((n) => n.equals(worldNormal));
            if (worldFace >= 0) {
                result.push({ worldFace, flavor: localFace });
            }
        }
        return result;
    }

    /** Number of faces (0..6) that currently have uniform color. */
    solvedFaceCount(): number {
        const faceColors: Array<Set<number>> = Array.from({ length: 6 }, () => new Set<number>());
        for (const cubie of this.cubies) {
            for (const { worldFace, flavor } of this.getWorldFaceFlavors(cubie)) {
                faceColors[worldFace].add(flavor);
            }
        }
        let solved = 0;
        for (const set of faceColors) {
            if (set.size === 1) solved++;
        }
        return solved;
    }

    isSolved(): boolean {
        return this.solvedFaceCount() === 6;
    }

    /** Checks if the cube matches a target pattern goal. */
    matchesGoal(goal: PatternGoal): boolean {
        if (goal === 'solved') return this.isSolved();

        // Collect 6 faces as maps of position -> flavor
        const faceStickers: Array<Array<{ pos: Int3; flavor: number }>> = Array.from(
            { length: 6 },
            () => [],
        );
        for (const cubie of this.cubies) {
            for (const { worldFace, flavor } of this.getWorldFaceFlavors(cubie)) {
                faceStickers[worldFace].push({ pos: cubie.pos, flavor });
            }
        }

        if (goal === 'checkerboard') {
            // Each face has 2 alternating colors (center vs corners vs edges).
            return faceStickers.every((stickers) => {
                const center = stickers.find(
                    (s) => (s.pos.x === 0 ? 1 : 0) + (s.pos.y === 0 ? 1 : 0) + (s.pos.z === 0 ? 1 : 0) === 2,
                );
                if (!center) return false;
                const colors = new Set(stickers.map((s) => s.flavor));
                if (colors.size !== 2) return false;
                return stickers.every((s) => {
                    const parity = (Math.abs(s.pos.x) + Math.abs(s.pos.y) + Math.abs(s.pos.z)) % 4 === 2;
                    // On 3x3: center has sum=2 (parity true), corners sum=6 (parity true), edges sum=4 (parity false)
                    return parity ? s.flavor === center.flavor : s.flavor !== center.flavor;
                });
            });
        }

        if (goal === 'donut') {
            // Center is different from the 8 surrounding ring stickers, which all match.
            return faceStickers.every((stickers) => {
                const center = stickers.find(
                    (s) => (s.pos.x === 0 ? 1 : 0) + (s.pos.y === 0 ? 1 : 0) + (s.pos.z === 0 ? 1 : 0) === 2,
                );
                if (!center) return false;
                const ringColors = new Set(
                    stickers.filter((s) => s !== center).map((s) => s.flavor),
                );
                return ringColors.size === 1 && !ringColors.has(center.flavor);
            });
        }

        if (goal === 'cross') {
            // M2 E2 pattern: 2 faces have a 5-sticker '+' cross, 4 faces have a 3-sticker stripe.
            let crossFaces = 0;
            let stripeFaces = 0;
            for (const stickers of faceStickers) {
                const center = stickers.find(
                    (s) => (s.pos.x === 0 ? 1 : 0) + (s.pos.y === 0 ? 1 : 0) + (s.pos.z === 0 ? 1 : 0) === 2,
                );
                if (!center) return false;
                const sameAsCenter = stickers.filter((s) => s.flavor === center.flavor).length;
                if (sameAsCenter === 5) crossFaces++;
                else if (sameAsCenter === 3) stripeFaces++;
                else return false;
            }
            return crossFaces === 2 && stripeFaces === 4;
        }

        return false;
    }
}
