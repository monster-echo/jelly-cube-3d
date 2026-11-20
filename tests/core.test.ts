import assert from 'node:assert/strict';
import {
    createSeededRng,
    invertMove,
    JellyCube,
    Mat3i,
    rotationMatrix,
} from '../assets/scripts/core/JellyEngine';
import {
    computeStars,
    getDailyChallengeDef,
    getLevelDef,
    setupCubeForLevel,
    TOTAL_LEVELS,
} from '../assets/scripts/core/JellyLevels';
import {
    formatDurationMs,
    getCheckInReward,
    getDailyStreakReward,
    getGlobalLeaderboard,
    getRecommendedChallenge,
} from '../assets/scripts/core/JellyLeaderboard';
import { getSkinById, hexToRgbNormalized, JELLY_SKINS } from '../assets/scripts/core/JellySkins';
import { defaultSaveData, loadSaveData, persistSaveData } from '../assets/scripts/core/JellyStorage';

// 1. Rotation matrices stay orthogonal and have determinant 1
for (let axis = 0; axis < 3; axis++) {
    for (let q = -4; q <= 4; q++) {
        const m = rotationMatrix(axis, q);
        assert.equal(m.isOrthogonal, true, `axis=${axis} q=${q} should be orthogonal`);
    }
}
assert.equal(Mat3i.IDENTITY.isOrthogonal, true);

// 2. Cube size cubie counts (2x2 -> 8, 3x3 -> 26, 4x4 -> 56, 5x5 -> 98, 9x9 -> 386)
assert.equal(new JellyCube(2).cubies.length, 8);
assert.equal(new JellyCube(3).cubies.length, 26);
assert.equal(new JellyCube(4).cubies.length, 56);
assert.equal(new JellyCube(5).cubies.length, 98);
assert.equal(new JellyCube(9).cubies.length, 386);
assert.equal(new JellyCube(10).cubies.length, 488);

// 3. Scramble & invert solution stack via hintNextMove
for (const size of [2, 3, 4, 5, 9, 10]) {
    const cube = new JellyCube(size);
    assert.equal(cube.isSolved(), true);
    const rng = createSeededRng(12345 + size);
    const moves = cube.scramble(10, rng);
    assert.equal(cube.isSolved(), false);

    // Solving via hintNextMove should always return to solved
    let guard = 0;
    while (!cube.isSolved() && guard < 30) {
        const hint = cube.hintNextMove();
        assert.ok(hint, 'hint should exist while unsolved');
        cube.applyMove(hint, true);
        guard++;
    }
    assert.equal(cube.isSolved(), true, `size ${size} should solve via hints`);
    assert.ok(guard <= moves.length, 'hints should not exceed scramble length');
}

// 4. Undo restores exact state
{
    const cube = new JellyCube(3);
    cube.applyMove({ axis: 0, coordinates: [2], quarterTurns: 1 }, true);
    assert.equal(cube.isSolved(), false);
    assert.equal(cube.canUndo, true);
    cube.undo();
    assert.equal(cube.isSolved(), true);
    assert.equal(cube.canUndo, false);
}

// 5. All 30 levels + daily challenge setup cleanly and are solvable via hints
for (let id = 1; id <= TOTAL_LEVELS; id++) {
    const level = getLevelDef(id);
    const cube = new JellyCube(level.cubeSize);
    setupCubeForLevel(cube, level);
    assert.equal(cube.matchesGoal(level.goal), false, `level ${id} should start unsolved`);

    let steps = 0;
    while (!cube.matchesGoal(level.goal) && steps < level.scrambleSteps + 2) {
        const hint = cube.hintNextMove();
        if (!hint) break;
        cube.applyMove(hint, true);
        steps++;
    }
    assert.equal(
        cube.matchesGoal(level.goal),
        true,
        `level ${id} (${level.goal}) should reach goal via hints`,
    );
}

{
    const daily = getDailyChallengeDef('2026-11-20');
    const cube = new JellyCube(daily.cubeSize);
    setupCubeForLevel(cube, daily);
    assert.equal(cube.isSolved(), false);
    assert.equal(computeStars(daily.parMoves, daily), 3);
    assert.equal(computeStars(daily.parMoves + 2, daily), 2);
    assert.equal(computeStars(daily.parMoves + 6, daily), 1);
}

// 6. Skins & storage
assert.equal(JELLY_SKINS.length, 10);
assert.equal(getSkinById('crystal').id, 'crystal');
assert.deepEqual(hexToRgbNormalized('#FF0080').map((v) => Math.round(v * 255)), [255, 0, 128]);

const save = defaultSaveData();
save.coins = 150;
save.unlockedLevel = 5;
persistSaveData(save);
const reloaded = loadSaveData();
assert.equal(reloaded.coins, 150);
assert.equal(reloaded.unlockedLevel, 5);

// Suppress unused import warning if invertMove is only used in levels
assert.ok(invertMove({ axis: 0, coordinates: [2], quarterTurns: 1 }).quarterTurns === -1);

// 7. Challenge recommendation & Global Leaderboard
assert.equal(getRecommendedChallenge(1).size, 3);
assert.equal(getRecommendedChallenge(12).size, 4);
assert.equal(getRecommendedChallenge(22).size, 5);
assert.equal(getRecommendedChallenge(28).size, 9);
assert.equal(getRecommendedChallenge(30).size, 10);
assert.equal(getDailyStreakReward(7).unlockSkinId, 'nebula');
assert.equal(getCheckInReward(1).coins, 30);
assert.equal(getCheckInReward(7).coins, 120);
assert.equal(defaultSaveData().coins, 120);
assert.equal(formatDurationMs(65400), '01:05.4');

const lb = getGlobalLeaderboard(9, '测试玩家', { timeMs: 260000, moves: 290, date: '2026-11-20' });
assert.equal(lb.playerRank, 3);
assert.ok(lb.beatPercent > 0);

console.log('All JellyCube3D core tests passed!');
