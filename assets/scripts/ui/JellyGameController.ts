// Jelly Cube 3D — Main Cocos Game Controller (Input, Modes, Timer, Replay, Skins, & Ads)

import {
    _decorator,
    Camera,
    Component,
    EventMouse,
    EventTouch,
    Input,
    input,
    Vec2,
    Vec3,
} from 'cc';
import { JellyCube, JellyMove, PatternGoal } from '../core/JellyEngine';
import {
    ChallengeSize,
    getCheckInReward,
    getDailyStreakReward,
    scrambleStepsForChallenge,
    submitGlobalScore,
} from '../core/JellyLeaderboard';
import {
    computeStars,
    getDailyChallengeDef,
    getLevelDef,
    JellyLevelDef,
    setupCubeForLevel,
    TOTAL_LEVELS,
} from '../core/JellyLevels';
import { getSkinById } from '../core/JellySkins';
import {
    JellySaveData,
    loadSaveData,
    persistSaveData,
    todayDateKey,
} from '../core/JellyStorage';
import { JellyAudio } from '../platform/JellyAudio';
import { PlatformBridge } from '../platform/PlatformBridge';
import { JellyCameraRig } from '../view/JellyCameraRig';
import { CubieHit, JellyCubeView } from '../view/JellyCubeView';

const { ccclass, property } = _decorator;

export type JellyPlayMode = 'level' | 'daily' | 'challenge' | 'free';

export interface GameUIState {
    onHome: boolean;
    playMode: JellyPlayMode;
    level: JellyLevelDef | null;
    challengeSize: ChallengeSize;
    freeSize: number;
    moves: number;
    elapsedMs: number;
    canUndo: boolean;
    solved: boolean;
    assistedSolve: boolean;
    coins: number;
    activeSkinId: string;
    unlockedSkins: string[];
    unlockedLevel: number;
    levelStars: Record<number, number>;
    bestRecords: JellySaveData['bestRecords'];
    dailyStreak: number;
    dailyDoneToday: boolean;
    lastDailyRewardLabel: string;
    playerId: string;
    playerName: string;
    lastPlayerMoveCount: number;
    muted: boolean;
    toast: string;
}

type StateListener = (state: GameUIState) => void;

interface ActiveDrag {
    startScreen: Vec2;
    hit: CubieHit;
    lockedAxis: number;
    lockedCoord: number;
    screenAxisDir: Vec2;
    angleDeg: number;
}

@ccclass('JellyGameController')
export class JellyGameController extends Component {
    @property(JellyCubeView)
    cubeView: JellyCubeView | null = null;

    @property(JellyCameraRig)
    cameraRig: JellyCameraRig | null = null;

    @property(Camera)
    camera: Camera | null = null;

    private _cube = new JellyCube(3);
    private _save: JellySaveData = loadSaveData();
    private _onHome = true;
    private _playMode: JellyPlayMode = 'level';
    private _currentLevel: JellyLevelDef = getLevelDef(1);
    private _challengeSize: ChallengeSize = 3;
    private _freeSize = 3;
    private _solved = false;
    private _paused = false;
    private _assistedSolve = false;
    private _autoSolving = false;
    private _replaying = false;
    private _sharedToday = false;
    private _toast = '';
    private _lastDailyRewardLabel = '';
    private _lastScrambleMoves: JellyMove[] = [];
    private _lastPlayerMoves: JellyMove[] = [];

    private _runStartMs: number | null = null;
    private _elapsedMs = 0;

    /** Set by the HUD while a modal covers the cube. */
    uiBlocking = false;
    /** Camera-drag mode: true while the rotate toggle is on. */
    rotateMode = false;

    private _drag: ActiveDrag | null = null;
    private _orbiting = false;
    private _lastTouch = new Vec2();
    private _listeners = new Set<StateListener>();

    start(): void {
        // cubeView/cameraRig are assigned by JellyBootstrap right after
        // addComponent; start runs after that wiring.
        JellyAudio.setMuted(this._save.muted);
        this.showHome();
        this._autoDailyCheckIn();
    }

    onEnable(): void {
        input.on(Input.EventType.TOUCH_START, this._onTouchStart, this);
        input.on(Input.EventType.TOUCH_MOVE, this._onTouchMove, this);
        input.on(Input.EventType.TOUCH_END, this._onTouchEnd, this);
        input.on(Input.EventType.TOUCH_CANCEL, this._onTouchEnd, this);
        input.on(Input.EventType.MOUSE_WHEEL, this._onMouseWheel, this);
    }

    onDisable(): void {
        input.off(Input.EventType.TOUCH_START, this._onTouchStart, this);
        input.off(Input.EventType.TOUCH_MOVE, this._onTouchMove, this);
        input.off(Input.EventType.TOUCH_END, this._onTouchEnd, this);
        input.off(Input.EventType.TOUCH_CANCEL, this._onTouchEnd, this);
        input.off(Input.EventType.MOUSE_WHEEL, this._onMouseWheel, this);
    }

    update(dt: number): void {
        if (this._onHome && !this._orbiting && this.cameraRig) {
            this.cameraRig.orbitBy(-dt * 45, 0);
        }
    }

    subscribe(fn: StateListener): () => void {
        this._listeners.add(fn);
        fn(this.getUIState());
        return () => this._listeners.delete(fn);
    }

    getCurrentElapsedMs(): number {
        if (this._runStartMs !== null && !this._solved && !this._paused) {
            return Date.now() - this._runStartMs;
        }
        return this._elapsedMs;
    }

    getUIState(): GameUIState {
        const today = todayDateKey();
        return {
            onHome: this._onHome,
            playMode: this._playMode,
            level: this._playMode === 'level' || this._playMode === 'daily' ? this._currentLevel : null,
            challengeSize: this._challengeSize,
            freeSize: this._freeSize,
            moves: this._cube.playerMoveCount,
            elapsedMs: this.getCurrentElapsedMs(),
            canUndo: this._cube.canUndo && !this._solved,
            solved: this._solved,
            assistedSolve: this._assistedSolve,
            coins: this._save.coins,
            activeSkinId: this._save.activeSkin,
            unlockedSkins: [...this._save.unlockedSkins],
            unlockedLevel: this._save.unlockedLevel,
            levelStars: { ...this._save.levelStars },
            bestRecords: { ...this._save.bestRecords },
            dailyStreak: this._save.dailyStreak,
            dailyDoneToday: this._save.dailyCompletedDate === today,
            lastDailyRewardLabel: this._lastDailyRewardLabel,
            playerId: this._save.playerId,
            playerName: this._save.playerName,
            lastPlayerMoveCount: this._lastPlayerMoves.length,
            muted: this._save.muted,
            toast: this._toast,
        };
    }

    private _emit(toast?: string): void {
        if (toast !== undefined) this._toast = toast;
        const snapshot = this.getUIState();
        for (const fn of this._listeners) fn(snapshot);
    }

    private _autoDailyCheckIn(): void {
        const today = todayDateKey();
        if (this._save.lastCheckInDate === today) return;
        this._save.lastCheckInDate = today;
        this._save.checkInStreak += 1;
        const reward = getCheckInReward(this._save.checkInStreak);
        this._save.coins += reward.coins;
        persistSaveData(this._save);
        this._emit(`Welcome back! ${reward.label}`);
    }

    private _resetTimer(): void {
        this._runStartMs = null;
        this._elapsedMs = 0;
        this._paused = false;
    }

    // --------------------------------------------------------- Navigation & Modes
    showHome(): void {
        this._onHome = true;
        this._autoSolving = false;
        this._replaying = false;
        this._paused = false;
        this._cube = new JellyCube(3);
        this.cubeView?.bindCube(this._cube);
        this.cubeView?.applySkin(getSkinById(this._save.activeSkin));
        this.cameraRig?.resetView(3);
        this._emit('');
    }

    startLevel(levelId: number): void {
        this._onHome = false;
        this._playMode = 'level';
        const clamped = Math.max(1, Math.min(TOTAL_LEVELS, levelId));
        this._currentLevel = getLevelDef(clamped);
        this._cube = new JellyCube(this._currentLevel.cubeSize);
        setupCubeForLevel(this._cube, this._currentLevel);
        this._solved = false;
        this._assistedSolve = false;
        this._autoSolving = false;
        this._resetTimer();

        this.cubeView?.bindCube(this._cube);
        this.cubeView?.applySkin(getSkinById(this._save.activeSkin));
        this.cameraRig?.resetView(this._currentLevel.cubeSize);
        this._emit('');
    }

    startDailyChallenge(): void {
        this._onHome = false;
        this._playMode = 'daily';
        this._currentLevel = getDailyChallengeDef(todayDateKey());
        this._cube = new JellyCube(this._currentLevel.cubeSize);
        setupCubeForLevel(this._cube, this._currentLevel);
        this._solved = false;
        this._assistedSolve = false;
        this._autoSolving = false;
        this._resetTimer();

        this.cubeView?.bindCube(this._cube);
        this.cubeView?.applySkin(getSkinById(this._save.activeSkin));
        this.cameraRig?.resetView(this._currentLevel.cubeSize);
        this._emit('');
    }

    startChallenge(size: ChallengeSize): void {
        this._onHome = false;
        this._playMode = 'challenge';
        this._challengeSize = size;
        this._cube = new JellyCube(size);
        this._lastScrambleMoves = this._cube.scramble(scrambleStepsForChallenge(size));
        this._solved = false;
        this._assistedSolve = false;
        this._autoSolving = false;
        this._resetTimer();

        this.cubeView?.bindCube(this._cube);
        this.cubeView?.applySkin(getSkinById(this._save.activeSkin));
        this.cameraRig?.resetView(size);
        this._emit(`${size}×${size} Speedrun ready! Twist to start`);
    }

    startFreePlay(size = this._freeSize): void {
        this._onHome = false;
        this._playMode = 'free';
        this._freeSize = size;
        this._cube = new JellyCube(size);
        this._lastScrambleMoves = this._cube.scramble(size === 2 ? 6 : size === 4 ? 14 : size >= 9 ? 20 : 10);
        this._solved = false;
        this._assistedSolve = false;
        this._autoSolving = false;
        this._resetTimer();

        this.cubeView?.bindCube(this._cube);
        this.cubeView?.applySkin(getSkinById(this._save.activeSkin));
        this.cameraRig?.resetView(size);
        this._emit('');
    }

    setPaused(paused: boolean): void {
        if (paused && !this._paused && this._runStartMs !== null && !this._solved) {
            this._elapsedMs = Date.now() - this._runStartMs;
            this._paused = true;
        } else if (!paused && this._paused) {
            if (this._runStartMs !== null) {
                this._runStartMs = Date.now() - this._elapsedMs;
            }
            this._paused = false;
        }
        this._emit();
    }

    undoMove(): void {
        if (this._solved || this._autoSolving || this._replaying) return;
        const inv = this._cube.undo();
        if (!inv) {
            this._emit('Nothing to undo');
            return;
        }
        this.cubeView?.syncImmediate();
        this.cubeView?.animateMove(inv, -inv.quarterTurns * 90, 0);
        JellyAudio.playSnap(-1);
        PlatformBridge.vibrate('light', this._save.haptics);
        this._emit();
    }

    resetCurrent(): void {
        if (this._playMode === 'level') this.startLevel(this._currentLevel.id);
        else if (this._playMode === 'daily') this.startDailyChallenge();
        else if (this._playMode === 'challenge') this.startChallenge(this._challengeSize);
        else this.startFreePlay(this._freeSize);
    }

    async triggerHint(useCoins: boolean): Promise<void> {
        if (this._solved || this._autoSolving) return;
        const hint = this._cube.hintNextMove();
        if (!hint) return;
        if (useCoins) {
            if (this._save.coins < 20) {
                this._emit('Need 20 🍬');
                return;
            }
            this._save.coins -= 20;
            persistSaveData(this._save);
        } else {
            const ok = await PlatformBridge.showRewardedAd('hint');
            if (!ok) return;
        }
        this.cubeView?.playHintMotion(hint);
        JellyAudio.playPoke();
        this._emit('Follow the highlighted slice direction');
    }

    async triggerTutorial(useCoins: boolean): Promise<void> {
        if (this._solved || this._autoSolving) return;
        if (useCoins) {
            if (this._save.coins < 60) {
                this._emit('Need 60 🍬');
                return;
            }
            this._save.coins -= 60;
            persistSaveData(this._save);
        } else {
            const ok = await PlatformBridge.showRewardedAd('hint');
            if (!ok) return;
        }
        this._assistedSolve = true;
        this._autoSolving = true;
        this._emit('Tutorial running (unranked)');

        const step = () => {
            if (!this._autoSolving || this._solved) return;
            const next = this._cube.hintNextMove();
            if (!next) {
                this._autoSolving = false;
                return;
            }
            this._applyCommittedMove(next, -next.quarterTurns * 90);
            if (!this._solved && this._autoSolving) {
                this.scheduleOnce(step, 0.36);
            }
        };
        this.scheduleOnce(step, 0.36);
    }

    replayLastSolve(onComplete: () => void): void {
        if (this._replaying || this._lastPlayerMoves.length === 0) return;
        this._replaying = true;
        if (this._playMode === 'level' || this._playMode === 'daily') {
            setupCubeForLevel(this._cube, this._currentLevel);
        } else {
            this._cube.applyPresetScramble(this._lastScrambleMoves);
        }
        this.cubeView?.bindCube(this._cube);
        this.cubeView?.applySkin(getSkinById(this._save.activeSkin));

        let idx = 0;
        const total = this._lastPlayerMoves.length;
        this._emit(`Replaying 0 / ${total}`);

        const step = () => {
            if (!this._replaying || idx >= total) {
                this._replaying = false;
                this.cubeView?.triggerSolveBounce();
                JellyAudio.playSolveChord();
                onComplete();
                return;
            }
            const m = this._lastPlayerMoves[idx++];
            this._cube.applyMove(m, false);
            this.cubeView?.syncImmediate();
            this.cubeView?.animateMove(m, -m.quarterTurns * 90, 0);
            JellyAudio.playSnap(this._cube.solvedFaceCount());
            this._emit(`Replaying ${idx} / ${total}`);
            this.scheduleOnce(step, 0.38);
        };
        this.scheduleOnce(step, 0.38);
    }

    async claimFreeSugarAd(): Promise<void> {
        const ok = await PlatformBridge.showRewardedAd('double_reward');
        if (!ok) return;
        this._save.coins += 30;
        persistSaveData(this._save);
        JellyAudio.playSolveChord();
        this._emit('Rewarded Ad complete! +30 🍬');
    }

    async claimDoubleRewardWithAd(): Promise<number> {
        const ok = await PlatformBridge.showRewardedAd('double_reward');
        if (!ok) return 0;
        const bonus =
            this._playMode === 'challenge'
                ? this._challengeSize * 8
                : this._playMode === 'free'
                  ? 20
                  : this._currentLevel.rewardCoins;
        this._save.coins += bonus;
        persistSaveData(this._save);
        this._emit(`2× Sugar +${bonus}!`);
        return bonus;
    }

    async shareForSugar(): Promise<void> {
        const ok = await PlatformBridge.shareGame(
            'Jelly Cube 3D',
            `I reached Level ${this._save.unlockedLevel} in Jelly Cube 3D!`,
        );
        if (ok && !this._sharedToday) {
            this._sharedToday = true;
            this._save.coins += 15;
            persistSaveData(this._save);
            JellyAudio.playSolveChord();
            this._emit('Shared! +15 🍬');
        }
    }

    rateApp(): void {
        PlatformBridge.openStoreReview();
    }

    selectOrUnlockSkin(skinId: string): boolean {
        const skin = getSkinById(skinId);
        if (this._save.unlockedSkins.includes(skin.id)) {
            this._save.activeSkin = skin.id;
            persistSaveData(this._save);
            this.cubeView?.applySkin(skin);
            this._emit(`Equipped: ${skin.name}`);
            return true;
        }
        if (this._save.coins < skin.cost) {
            this._emit(`Need ${skin.cost} 🍬`);
            return false;
        }
        this._save.coins -= skin.cost;
        this._save.unlockedSkins.push(skin.id);
        this._save.activeSkin = skin.id;
        persistSaveData(this._save);
        this.cubeView?.applySkin(skin);
        JellyAudio.playSolveChord();
        this._emit(`Unlocked: ${skin.name}!`);
        return true;
    }

    toggleMute(): void {
        this._save.muted = !this._save.muted;
        JellyAudio.setMuted(this._save.muted);
        persistSaveData(this._save);
        this._emit();
    }

    // --------------------------------------------------------- Touch & 3D Gesture
    private _onTouchStart(e: EventTouch): void {
        const loc = e.getLocation();
        this._lastTouch.set(loc.x, loc.y);

        if (this.uiBlocking || this._autoSolving || this._replaying || this._paused) {
            this._orbiting = true;
            return;
        }
        if (this._onHome || this.rotateMode) {
            this._orbiting = true;
            return;
        }

        const hit = this.cubeView?.pickCubelet(loc.x, loc.y) ?? null;
        if (hit && !this._solved) {
            PlatformBridge.setBannerVisible(false);
            this._drag = {
                startScreen: new Vec2(loc.x, loc.y),
                hit,
                lockedAxis: -1,
                lockedCoord: 0,
                screenAxisDir: new Vec2(1, 0),
                angleDeg: 0,
            };
            return;
        }

        // Play mode: a drag off the cube is ignored so a near miss never
        // spins the camera; the rotate toggle owns camera gestures instead.
        this._orbiting = false;
    }

    private _onTouchMove(e: EventTouch): void {
        const loc = e.getLocation();
        const dx = loc.x - this._lastTouch.x;
        const dy = loc.y - this._lastTouch.y;
        this._lastTouch.set(loc.x, loc.y);

        if (this._orbiting) {
            this.cameraRig?.orbitBy(dx, dy);
            return;
        }

        if (!this._drag || !this.camera) return;

        const totalDx = loc.x - this._drag.startScreen.x;
        const totalDy = loc.y - this._drag.startScreen.y;
        const totalDist = Math.hypot(totalDx, totalDy);
        if (totalDist < 18) return;
        if (this._drag.lockedAxis < 0) {
            this._lockSliceAxis(new Vec2(totalDx, totalDy));
        } else if (totalDist < 80) {
            this._maybeRelock(new Vec2(totalDx, totalDy));
        }

        if (this._drag.lockedAxis >= 0) {
            const totalDx = loc.x - this._drag.startScreen.x;
            const totalDy = loc.y - this._drag.startScreen.y;
            const proj = totalDx * this._drag.screenAxisDir.x + totalDy * this._drag.screenAxisDir.y;
            this._drag.angleDeg = Math.max(-135, Math.min(135, proj * 0.48));
            this.cubeView?.setInteractiveTurn(
                this._drag.lockedAxis,
                this._drag.lockedCoord,
                this._drag.angleDeg,
            );
        }
    }

    private _onTouchEnd(): void {
        this._orbiting = false;
        // Banner belongs to the home screen only; in-game it covered the dock.
        PlatformBridge.setBannerVisible(this._onHome && !this.uiBlocking);

        if (!this._drag) return;
        const drag = this._drag;
        this._drag = null;
        this.cubeView?.clearInteractiveTurn();

        if (drag.lockedAxis < 0) return;

        const travelled = Math.hypot(
            this._lastTouch.x - drag.startScreen.x,
            this._lastTouch.y - drag.startScreen.y,
        );
        if (travelled < 24) {
            this.cubeView?.animateMove(
                { axis: drag.lockedAxis, coordinates: [drag.lockedCoord], quarterTurns: 0 },
                0,
                0,
            );
            return;
        }

        const quarters = Math.round(drag.angleDeg / 90);
        if (quarters !== 0) {
            const move: JellyMove = {
                axis: drag.lockedAxis,
                coordinates: [drag.lockedCoord],
                quarterTurns: quarters,
            };
            const residual = drag.angleDeg - quarters * 90;
            this._applyCommittedMove(move, residual);
        } else {
            this.cubeView?.animateMove(
                { axis: drag.lockedAxis, coordinates: [drag.lockedCoord], quarterTurns: 0 },
                drag.angleDeg,
                0,
            );
        }
    }

    private _onMouseWheel(e: EventMouse): void {
        this.cameraRig?.zoomBy(-e.getScrollY() * 0.005);
    }

    // Two in-plane axes can be dragged on the touched face. Score both by how
    // well the gesture projects onto their screen-space tangents, and only
    // commit to one once the gesture is long and clearly dominant; this is
    // what stops a diagonal flick from picking the wrong axis.
    private _axisScores(dragVec: Vec2): Array<{ axis: number; dir: Vec2; score: number }> {
        const drag = this._drag;
        if (!drag || !this.camera) return [];
        const n = drag.hit.worldNormal;
        const p = drag.hit.worldPoint;
        const originScreen = this.camera.worldToScreen(p);

        const nAxis = Math.abs(n.x) > 0.5 ? 0 : Math.abs(n.y) > 0.5 ? 1 : 2;
        const out: Array<{ axis: number; dir: Vec2; score: number }> = [];
        for (let axis = 0; axis < 3; axis++) {
            if (axis === nAxis) continue;
            const axisV = new Vec3(axis === 0 ? 1 : 0, axis === 1 ? 1 : 0, axis === 2 ? 1 : 0);
            const tangent = new Vec3();
            Vec3.cross(tangent, axisV, n);
            const tipWorld = new Vec3(
                p.x + tangent.x * 0.5,
                p.y + tangent.y * 0.5,
                p.z + tangent.z * 0.5,
            );
            const tipScreen = this.camera.worldToScreen(tipWorld);
            const dir = new Vec2(tipScreen.x - originScreen.x, tipScreen.y - originScreen.y);
            const len = dir.length();
            if (len < 0.001) continue;
            dir.multiplyScalar(1 / len);
            out.push({ axis, dir, score: Math.abs(dragVec.x * dir.x + dragVec.y * dir.y) });
        }
        out.sort((a, b) => b.score - a.score);
        return out;
    }

    private _applyAxisLock(pick: { axis: number; dir: Vec2 }): void {
        if (!this._drag) return;
        this._drag.lockedAxis = pick.axis;
        this._drag.lockedCoord = this._drag.hit.cubie.pos.at(pick.axis);
        this._drag.screenAxisDir = pick.dir;
        PlatformBridge.vibrate('light', this._save?.haptics ?? true);
    }

    private _lockSliceAxis(dragVec: Vec2): void {
        const scores = this._axisScores(dragVec);
        if (scores.length === 0) return;
        const [best, second] = scores;
        const dist = dragVec.length();
        const ratio = best.score / Math.max(0.001, second?.score ?? 0);
        // Short gesture: needs a clear winner. Longer gesture: accept the best.
        if (ratio < 1.25 && dist < 42) return;
        this._applyAxisLock(best);
    }

    private _maybeRelock(dragVec: Vec2): void {
        if (!this._drag || this._drag.lockedAxis < 0) return;
        const locked = this._drag.lockedAxis;
        const scores = this._axisScores(dragVec);
        const best = scores[0];
        if (!best || best.axis === locked) return;
        const current = scores.find((x) => x.axis === locked);
        if (!current) return;
        // Let a deliberate change of direction win before the turn commits.
        if (best.score > current.score * 1.6 && best.score > 26) {
            this._applyAxisLock(best);
        }
    }

    private _applyCommittedMove(move: JellyMove, residualAngleDeg: number): void {
        if (this._runStartMs === null) {
            this._runStartMs = Date.now();
        }
        this._cube.applyMove(move, true);
        this.cubeView?.syncImmediate();
        this.cubeView?.animateMove(move, residualAngleDeg, 0);
        JellyAudio.playSnap(this._cube.solvedFaceCount());
        PlatformBridge.vibrate('light', this._save.haptics);

        const goal: PatternGoal =
            this._playMode === 'free' || this._playMode === 'challenge'
                ? 'solved'
                : this._currentLevel.goal;
        if (this._cube.matchesGoal(goal)) {
            this._onGoalReached();
        } else {
            this._emit();
        }
    }

    private _onGoalReached(): void {
        this._solved = true;
        this._autoSolving = false;
        this._elapsedMs = this._runStartMs !== null ? Date.now() - this._runStartMs : 0;
        this._lastPlayerMoves = this._cube.getPlayerMoves();
        this._lastDailyRewardLabel = '';

        this.cubeView?.triggerSolveBounce();
        JellyAudio.playSolveChord();
        PlatformBridge.vibrate('success', this._save.haptics);

        if (!this._assistedSolve) {
            if (this._playMode === 'level') {
                const stars = computeStars(this._cube.playerMoveCount, this._currentLevel);
                const prev = this._save.levelStars[this._currentLevel.id] ?? 0;
                if (stars > prev) this._save.levelStars[this._currentLevel.id] = stars;
                if (
                    this._currentLevel.id >= this._save.unlockedLevel &&
                    this._currentLevel.id < TOTAL_LEVELS
                ) {
                    this._save.unlockedLevel = this._currentLevel.id + 1;
                }
                this._save.coins += this._currentLevel.rewardCoins;
                if (this._currentLevel.id % 3 === 0) {
                    PlatformBridge.showInterstitialAd('level_complete');
                }
            } else if (this._playMode === 'daily') {
                const today = todayDateKey();
                if (this._save.dailyCompletedDate !== today) {
                    this._save.dailyCompletedDate = today;
                    this._save.dailyStreak += 1;
                    const rewardInfo = getDailyStreakReward(this._save.dailyStreak);
                    this._save.coins += rewardInfo.coins;
                    if (
                        rewardInfo.unlockSkinId &&
                        !this._save.unlockedSkins.includes(rewardInfo.unlockSkinId)
                    ) {
                        this._save.unlockedSkins.push(rewardInfo.unlockSkinId);
                    }
                    this._lastDailyRewardLabel = rewardInfo.label;
                }
            } else if (this._playMode === 'challenge') {
                const rec = {
                    timeMs: Math.round(this._elapsedMs),
                    moves: this._cube.playerMoveCount,
                    date: todayDateKey(),
                };
                const prev = this._save.bestRecords[this._challengeSize];
                if (!prev || this._elapsedMs < prev.timeMs) {
                    this._save.bestRecords[this._challengeSize] = rec;
                }
                submitGlobalScore(this._challengeSize, this._save.playerId, this._save.playerName, rec);
                this._save.coins += this._challengeSize * 8;
            } else {
                this._save.coins += 20;
            }
            persistSaveData(this._save);
        }

        this._emit();
    }
}
