// Jelly Cube 3D — Endgame Level Progression & Daily Challenge Generator.

import {
    createSeededRng,
    invertMove,
    JellyCube,
    JellyMove,
    PatternGoal,
} from './JellyEngine';

export interface JellyLevelDef {
    id: number;
    title: string;
    subtitle: string;
    cubeSize: number;
    scrambleSteps: number;
    parMoves: number;
    maxMoves: number;
    goal: PatternGoal;
    seed: number;
    rewardCoins: number;
}

const LEVEL_TITLES: ReadonlyArray<{ title: string; subtitle: string }> = [
    { title: 'First Squish', subtitle: '1 move to feel the jelly snap' },
    { title: 'Double Bounce', subtitle: '2 moves · find the slice direction' },
    { title: '3×3 Warmup', subtitle: 'Your first 3×3 jelly twist' },
    { title: 'Lemon Corner', subtitle: '2 moves · quick & juicy' },
    { title: 'Lime Cross', subtitle: '3 moves · match adjacent colors' },
    { title: 'Cherry Core', subtitle: '3 moves · watch the middle' },
    { title: 'Berry Swirl', subtitle: '4 moves · aim for 3 stars' },
    { title: 'Tangerine Twist', subtitle: '4 moves · smooth rhythm' },
    { title: 'Rainbow Plate', subtitle: '5 moves · stay sharp' },
    { title: 'Jelly Stairs', subtitle: '5 moves · precision turns' },
    { title: 'Checkerboard', subtitle: 'Pattern: alternating checkerboard' },
    { title: 'Sugar Cross', subtitle: 'Pattern: 4-way center cross' },
    { title: 'Berry Heart', subtitle: '6 moves · use Undo freely' },
    { title: 'Caramel Vortex', subtitle: '6 moves · keep your flow' },
    { title: 'Crystal Maze', subtitle: '7 moves · check the back faces' },
    { title: 'Jelly Donut', subtitle: 'Pattern: center ring donut' },
    { title: 'Fizzy Pop', subtitle: '7 moves · step by step' },
    { title: 'Dual Harmony', subtitle: '8 moves · speedrun warmup' },
    { title: 'Matcha Grid', subtitle: '8 moves · pro territory' },
    { title: '4×4 Debut', subtitle: 'Welcome to 4×4 jelly!' },
    { title: 'Jelly Master I', subtitle: '9 moves · stay focused' },
    { title: 'Jelly Master II', subtitle: '10 moves · deep scramble' },
    { title: 'Starlight Cross', subtitle: 'Advanced pattern solve' },
    { title: '4×4 Cyclone', subtitle: '4×4 deeper scramble' },
    { title: 'Dessert Tower', subtitle: '12 moves · master challenge' },
];

export const TOTAL_LEVELS = 30;

export function getLevelDef(levelId: number): JellyLevelDef {
    const id = Math.max(1, Math.min(TOTAL_LEVELS, levelId));
    const meta = LEVEL_TITLES[(id - 1) % LEVEL_TITLES.length];

    let cubeSize = 3;
    let scrambleSteps = 3;
    let goal: PatternGoal = 'solved';

    if (id <= 2) {
        cubeSize = 2;
        scrambleSteps = id; // 1, 2
    } else if (id <= 10) {
        cubeSize = 3;
        scrambleSteps = Math.min(5, Math.floor((id - 1) / 2) + 1); // 2..5
    } else if (id === 11) {
        cubeSize = 3;
        scrambleSteps = 4;
        goal = 'checkerboard';
    } else if (id === 12) {
        cubeSize = 3;
        scrambleSteps = 4;
        goal = 'cross';
    } else if (id === 16) {
        cubeSize = 3;
        scrambleSteps = 5;
        goal = 'donut';
    } else if (id === 20 || id === 24 || id >= 28) {
        cubeSize = 4;
        scrambleSteps = id === 20 ? 3 : id === 24 ? 5 : 7;
    } else {
        cubeSize = 3;
        scrambleSteps = Math.min(12, 5 + Math.floor((id - 12) / 2));
    }

    const parMoves = scrambleSteps;
    const maxMoves = scrambleSteps + Math.max(4, Math.ceil(scrambleSteps * 1.2));
    const rewardCoins = 15 + id * 3;

    return {
        id,
        title: id > LEVEL_TITLES.length ? `Jelly Trial #${id}` : meta.title,
        subtitle: meta.subtitle,
        cubeSize,
        scrambleSteps,
        parMoves,
        maxMoves,
        goal,
        seed: 20261120 + id * 7919,
        rewardCoins,
    };
}

export function getDailyChallengeDef(dateKey: string): JellyLevelDef {
    let hash = 2166136261;
    for (let i = 0; i < dateKey.length; i++) {
        hash ^= dateKey.charCodeAt(i);
        hash = Math.imul(hash, 16777619);
    }
    return {
        id: 0,
        title: `Daily · ${dateKey}`,
        subtitle: 'Global daily seed · Streak rewards',
        cubeSize: 3,
        scrambleSteps: 8,
        parMoves: 8,
        maxMoves: 24,
        goal: 'solved',
        seed: hash >>> 0,
        rewardCoins: 60,
    };
}

/**
 * Sets up a JellyCube for a given level (including pattern levels where the
 * target pattern is scrambled from the pattern state, or solved levels scrambled
 * from solved state).
 */
export function setupCubeForLevel(cube: JellyCube, level: JellyLevelDef): JellyMove[] {
    cube.reset();
    const rng = createSeededRng(level.seed);

    const sixSpotMoves: JellyMove[] = [
        { axis: 1, coordinates: [2], quarterTurns: -1 },
        { axis: 1, coordinates: [-2], quarterTurns: -1 },
        { axis: 0, coordinates: [2], quarterTurns: -1 },
        { axis: 0, coordinates: [-2], quarterTurns: -1 },
        { axis: 2, coordinates: [2], quarterTurns: -1 },
        { axis: 2, coordinates: [-2], quarterTurns: -1 },
        { axis: 1, coordinates: [2], quarterTurns: -1 },
        { axis: 1, coordinates: [-2], quarterTurns: -1 },
    ];

    if (level.goal === 'checkerboard') {
        const preset: JellyMove[] = [
            { axis: 0, coordinates: [-2, 2], quarterTurns: 2 },
            { axis: 1, coordinates: [-2, 2], quarterTurns: 2 },
            { axis: 2, coordinates: [-2, 2], quarterTurns: 2 },
        ];
        for (const m of preset) cube.applyMove(m, false);
        cube.markGoalBase();
    } else if (level.goal === 'donut') {
        for (const m of sixSpotMoves) cube.applyMove(m, false);
        cube.markGoalBase();
    } else if (level.goal === 'cross') {
        const crossSetup: JellyMove[] = [
            { axis: 0, coordinates: [0], quarterTurns: 2 },
            { axis: 1, coordinates: [0], quarterTurns: 2 },
        ];
        for (const m of crossSetup) cube.applyMove(m, false);
        cube.markGoalBase();
    }

    const moves = cube.scramble(level.scrambleSteps, rng);
    return moves.map(invertMove).reverse();
}

export function computeStars(movesUsed: number, level: JellyLevelDef): 1 | 2 | 3 {
    if (movesUsed <= level.parMoves) return 3;
    if (movesUsed <= level.parMoves + 3) return 2;
    return 1;
}
