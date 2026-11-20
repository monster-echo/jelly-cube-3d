import { JellyCube, JellyMove } from '../../assets/scripts/core/JellyEngine';
import {
    CHALLENGE_SIZES,
    ChallengeSize,
    fetchGlobalLeaderboard,
    formatDurationMs,
    getCheckInReward,
    getDailyStreakReward,
    getGlobalLeaderboard,
    getRecommendedChallenge,
    scrambleStepsForChallenge,
    submitGlobalScore,
} from '../../assets/scripts/core/JellyLeaderboard';
import {
    computeStars,
    getDailyChallengeDef,
    getLevelDef,
    JellyLevelDef,
    setupCubeForLevel,
    TOTAL_LEVELS,
} from '../../assets/scripts/core/JellyLevels';
import { getSkinById, JELLY_SKINS } from '../../assets/scripts/core/JellySkins';
import { loadSaveData, persistSaveData, todayDateKey } from '../../assets/scripts/core/JellyStorage';
import { JellyAudio } from '../../assets/scripts/platform/JellyAudio';
import { JellyWebGLRenderer, WebHit } from './jellyGL';

const canvas = document.getElementById('gl-canvas') as HTMLCanvasElement;
const hudTop = document.getElementById('hud-top')!;
const hudBottom = document.getElementById('hud-bottom')!;
const homeScreen = document.getElementById('home-screen')!;
const homeCoinsEl = document.getElementById('home-coins')!;
const homeLvlEl = document.getElementById('home-lvl')!;
const homeStreakEl = document.getElementById('home-streak')!;
const titleEl = document.getElementById('hud-title')!;
const subEl = document.getElementById('hud-sub')!;
const coinsEl = document.getElementById('hud-coins')!;
const toastEl = document.getElementById('toast')!;
const modalBackdrop = document.getElementById('modal-backdrop')!;
const modalCard = document.getElementById('modal-card')!;

let save = loadSaveData();
JellyAudio.setMuted(save.muted);

const renderer = new JellyWebGLRenderer(canvas, getSkinById(save.activeSkin));
let onHome = true;
let playMode: 'level' | 'daily' | 'challenge' | 'free' = 'level';
let level: JellyLevelDef = getLevelDef(save.unlockedLevel);
let freeSize = 3;
let challengeSize: ChallengeSize = 3;
let cube = new JellyCube(level.cubeSize);
let solved = false;
let paused = false;
let assistedSolve = false;
let autoSolving = false;
let replaying = false;
let lastScrambleMoves: JellyMove[] = [];
let lastPlayerMoves: JellyMove[] = [];
let lastDailyRewardLabel = '';
let doubleClaimed = false;
let toastTimer: number | null = null;
let runStartMs: number | null = null;
let elapsedMs = 0;

function showHome() {
    onHome = true;
    autoSolving = false;
    homeScreen.classList.remove('hidden');
    hudTop.classList.add('hidden');
    hudBottom.classList.add('hidden');
    homeCoinsEl.textContent = String(save.coins);
    homeLvlEl.textContent = String(save.unlockedLevel);
    homeStreakEl.textContent = String(save.dailyStreak);
    cube = new JellyCube(3);
    renderer.bindCube(cube);
    renderer.applySkin(getSkinById(save.activeSkin));
}

function enterGame() {
    onHome = false;
    homeScreen.classList.add('hidden');
    hudTop.classList.remove('hidden');
    hudBottom.classList.remove('hidden');
}

function resetTimer() {
    runStartMs = null;
    elapsedMs = 0;
    paused = false;
}

function currentElapsedMs(): number {
    if (runStartMs !== null && !solved && !paused) {
        return performance.now() - runStartMs;
    }
    return elapsedMs;
}

function showToast(msg: string) {
    toastEl.textContent = msg;
    if (toastTimer) window.clearTimeout(toastTimer);
    toastTimer = window.setTimeout(() => {
        toastEl.textContent = '';
    }, 1800);
}

function updateHUD() {
    const tStr = formatDurationMs(currentElapsedMs());
    if (playMode === 'level') {
        titleEl.textContent = `Level ${level.id}`;
        subEl.textContent = `${cube.playerMoveCount}/${level.parMoves} · ${tStr}`;
    } else if (playMode === 'daily') {
        titleEl.textContent = 'Daily';
        subEl.textContent = `${cube.playerMoveCount} moves · ${tStr}`;
    } else if (playMode === 'challenge') {
        titleEl.textContent = `${challengeSize}×${challengeSize} Race`;
        subEl.textContent = `${cube.playerMoveCount} moves · ${tStr}`;
    } else {
        titleEl.textContent = `Free ${freeSize}×${freeSize}`;
        subEl.textContent = `${cube.playerMoveCount} moves · ${tStr}`;
    }
    coinsEl.textContent = String(save.coins);
    homeCoinsEl.textContent = String(save.coins);
    homeLvlEl.textContent = String(save.unlockedLevel);
    homeStreakEl.textContent = String(save.dailyStreak);
}

function startLevel(id: number) {
    enterGame();
    playMode = 'level';
    level = getLevelDef(id);
    cube = new JellyCube(level.cubeSize);
    setupCubeForLevel(cube, level);
    solved = false;
    assistedSolve = false;
    autoSolving = false;
    resetTimer();
    renderer.bindCube(cube);
    renderer.applySkin(getSkinById(save.activeSkin));
    updateHUD();
}

function startDaily() {
    enterGame();
    playMode = 'daily';
    level = getDailyChallengeDef(todayDateKey());
    cube = new JellyCube(level.cubeSize);
    setupCubeForLevel(cube, level);
    solved = false;
    assistedSolve = false;
    autoSolving = false;
    resetTimer();
    renderer.bindCube(cube);
    renderer.applySkin(getSkinById(save.activeSkin));
    updateHUD();
}

function startChallenge(size: ChallengeSize) {
    enterGame();
    playMode = 'challenge';
    challengeSize = size;
    cube = new JellyCube(size);
    lastScrambleMoves = cube.scramble(scrambleStepsForChallenge(size));
    solved = false;
    assistedSolve = false;
    autoSolving = false;
    resetTimer();
    renderer.bindCube(cube);
    renderer.applySkin(getSkinById(save.activeSkin));
    updateHUD();
    showToast(`${size}×${size} Speedrun ready! Twist to start timer`);
}

function startFree(size: number) {
    enterGame();
    playMode = 'free';
    freeSize = size;
    cube = new JellyCube(size);
    lastScrambleMoves = cube.scramble(size === 2 ? 6 : size === 4 ? 14 : size >= 9 ? 20 : 10);
    solved = false;
    assistedSolve = false;
    autoSolving = false;
    resetTimer();
    renderer.bindCube(cube);
    renderer.applySkin(getSkinById(save.activeSkin));
    updateHUD();
}

function commitMove(move: JellyMove, residualDeg: number) {
    if (runStartMs === null) {
        runStartMs = performance.now();
    }
    cube.applyMove(move, true);
    renderer.animateMove(move, residualDeg);
    JellyAudio.playSnap(cube.solvedFaceCount());

    const goal = playMode === 'free' || playMode === 'challenge' ? 'solved' : level.goal;
    if (cube.matchesGoal(goal)) {
        solved = true;
        autoSolving = false;
        elapsedMs = runStartMs !== null ? performance.now() - runStartMs : 0;
        lastPlayerMoves = cube.getPlayerMoves();
        lastDailyRewardLabel = '';
        doubleClaimed = false;
        renderer.triggerSolveBounce();
        JellyAudio.playSolveChord();
        if (!assistedSolve) {
            if (playMode === 'level') {
                const stars = computeStars(cube.playerMoveCount, level);
                save.levelStars[level.id] = Math.max(save.levelStars[level.id] ?? 0, stars);
                if (level.id >= save.unlockedLevel && level.id < TOTAL_LEVELS) {
                    save.unlockedLevel = level.id + 1;
                }
                save.coins += level.rewardCoins;
            } else if (playMode === 'daily') {
                const today = todayDateKey();
                if (save.dailyCompletedDate !== today) {
                    save.dailyCompletedDate = today;
                    save.dailyStreak += 1;
                    const rewardInfo = getDailyStreakReward(save.dailyStreak);
                    save.coins += rewardInfo.coins;
                    if (rewardInfo.unlockSkinId && !save.unlockedSkins.includes(rewardInfo.unlockSkinId)) {
                        save.unlockedSkins.push(rewardInfo.unlockSkinId);
                    }
                    lastDailyRewardLabel = rewardInfo.label;
                }
            } else if (playMode === 'challenge') {
                const rec = {
                    timeMs: Math.round(elapsedMs),
                    moves: cube.playerMoveCount,
                    date: todayDateKey(),
                };
                const prev = save.bestRecords[challengeSize];
                if (!prev || elapsedMs < prev.timeMs) {
                    save.bestRecords[challengeSize] = rec;
                }
                submitGlobalScore(challengeSize, save.playerId, save.playerName, rec);
                save.coins += challengeSize * 8;
            } else {
                save.coins += 20;
            }
            persistSaveData(save);
        }
        openWinModal();
    }
    updateHUD();
}

function openModal(html: string) {
    modalCard.innerHTML = html;
    modalBackdrop.classList.remove('hidden');
}

function closeModal() {
    modalBackdrop.classList.add('hidden');
}

function replayLastSolve() {
    if (replaying || lastPlayerMoves.length === 0) return;
    closeModal();
    replaying = true;
    // Reset cube to exact starting state of that run
    if (playMode === 'level' || playMode === 'daily') {
        setupCubeForLevel(cube, level);
    } else {
        cube.applyPresetScramble(lastScrambleMoves);
    }
    renderer.bindCube(cube);
    renderer.applySkin(getSkinById(save.activeSkin));

    let idx = 0;
    const total = lastPlayerMoves.length;
    showToast(`Replaying 0 / ${total}`);
    const timer = window.setInterval(() => {
        if (!replaying || idx >= total) {
            replaying = false;
            window.clearInterval(timer);
            renderer.triggerSolveBounce();
            JellyAudio.playSolveChord();
            openWinModal();
            return;
        }
        const m = lastPlayerMoves[idx++];
        cube.applyMove(m, false);
        renderer.animateMove(m, -m.quarterTurns * 90);
        JellyAudio.playSnap(cube.solvedFaceCount());
        showToast(`Replaying ${idx} / ${total}`);
    }, 380);
}

function openWinModal() {
    if (assistedSolve) {
        openModal(`
          <div class="modal-title">Tutorial Complete</div>
          <p style="color:#664e76;font-size:14px;line-height:1.6;">
            Step-by-step solve tutorial finished!<br/>
            <strong>Tutorial runs do not count toward stars or global rankings.</strong>
          </p>
          <button class="modal-btn primary" id="m-retry-clean">Try It Yourself</button>
          <button class="modal-btn secondary" id="m-go-home">Back to Home</button>
        `);
        document.getElementById('m-retry-clean')?.addEventListener('click', () => {
            closeModal();
            if (playMode === 'level') startLevel(level.id);
            else if (playMode === 'daily') startDaily();
            else if (playMode === 'challenge') startChallenge(challengeSize);
            else startFree(freeSize);
        });
        document.getElementById('m-go-home')?.addEventListener('click', () => {
            closeModal();
            function autoDailyCheckIn() {
    const today = todayDateKey();
    if (save.lastCheckInDate === today) return;
    save.lastCheckInDate = today;
    save.checkInStreak += 1;
    const reward = getCheckInReward(save.checkInStreak);
    save.coins += reward.coins;
    persistSaveData(save);
    updateHUD();
    showToast(`Welcome back! ${reward.label}`);
}

showHome();
autoDailyCheckIn();
        });
        return;
    }

    const stars = playMode === 'free' || playMode === 'challenge' ? 3 : computeStars(cube.playerMoveCount, level);
    const reward =
        playMode === 'challenge' ? challengeSize * 8 : playMode === 'free' ? 20 : level.rewardCoins;
    const timeStr = formatDurationMs(elapsedMs);
    let extraInfo = '';
    if (playMode === 'challenge') {
        const lb = getGlobalLeaderboard(challengeSize, save.playerName, save.bestRecords[challengeSize]);
        extraInfo = `<div style="color:#7448f5;font-weight:700;font-size:14px;margin-bottom:6px;">🏆 ${challengeSize}×${challengeSize} Global Rank #${lb.playerRank} (Top ${100 - lb.beatPercent}%)</div>`;
    } else if (playMode === 'daily' && lastDailyRewardLabel) {
        extraInfo = `<div style="color:#7448f5;font-weight:700;font-size:14px;margin-bottom:6px;">🔥 ${lastDailyRewardLabel}</div>`;
    }
    openModal(`
      <div class="modal-title">Jelly Solved!</div>
      <div class="stars-big">${'★'.repeat(stars)}${'☆'.repeat(3 - stars)}</div>
      ${extraInfo}
      <p style="color:#664e76;font-size:14px;">Time: ${timeStr} · ${cube.playerMoveCount} moves · +${reward} 🍬</p>
      ${lastPlayerMoves.length > 0 ? `<button class="modal-btn secondary" id="m-replay">🎬 Watch Replay (${lastPlayerMoves.length} moves)</button>` : ''}
      ${doubleClaimed ? '' : `<button class="modal-btn gold" id="m-double">Watch Ad for 2× Sugar (+${reward})</button>`}
      ${playMode === 'challenge' ? `<button class="modal-btn secondary" id="m-lb">Global Leaderboard</button>` : ''}
      <button class="modal-btn primary" id="m-next">${playMode === 'level' && level.id < TOTAL_LEVELS ? 'Next Level' : 'Play Again'}</button>
    `);
    document.getElementById('m-replay')?.addEventListener('click', replayLastSolve);
    document.getElementById('m-double')?.addEventListener('click', () => {
        doubleClaimed = true;
        save.coins += reward;
        persistSaveData(save);
        updateHUD();
        openWinModal();
        showToast(`2× Sugar +${reward}!`);
    });
    document.getElementById('m-lb')?.addEventListener('click', () => openChallengeModal(challengeSize));
    document.getElementById('m-next')?.addEventListener('click', () => {
        closeModal();
        if (playMode === 'level' && level.id < TOTAL_LEVELS) startLevel(level.id + 1);
        else if (playMode === 'daily') startDaily();
        else if (playMode === 'challenge') startChallenge(challengeSize);
        else startFree(freeSize);
    });
}

async function openChallengeModal(tabSize: ChallengeSize = challengeSize) {
    const rec = getRecommendedChallenge(save.unlockedLevel);
    const lb = await fetchGlobalLeaderboard(
        tabSize,
        save.playerId,
        save.playerName,
        save.bestRecords[tabSize],
    );
    const tabs = CHALLENGE_SIZES.map(
        (s) => `<button class="lb-tab ${s === tabSize ? 'active' : ''}" data-lb-size="${s}">${s}×${s}</button>`,
    ).join('');
    const rows = lb.entries
        .map(
            (e) => `
          <div class="lb-row ${e.isPlayer ? 'me' : ''}">
            <span class="lb-rank">#${e.rank}</span>
            <span class="lb-name">${e.name} <small style="opacity:0.6">${e.region}</small></span>
            <span class="lb-time">${formatDurationMs(e.timeMs)} · ${e.moves}m</span>
          </div>`,
        )
        .join('');

    openModal(`
      <div class="shop-header">
        <div class="modal-title" style="margin:0;">Global Leaderboard</div>
        <div style="display:flex;align-items:center;gap:8px;">
          <button class="rec-btn" id="m-rec-go" style="background:#f2eaf8;padding:6px 10px;font-size:12px;">${rec.size}×${rec.size} Pick</button>
          <button class="modal-close-x" id="m-close" aria-label="Close">✕</button>
        </div>
      </div>
      <div class="lb-tabs">${tabs}</div>
      <div class="lb-list">${rows}</div>
      <button class="modal-btn primary" id="m-start-tab">Start ${tabSize}×${tabSize} Race</button>
    `);

    document.getElementById('m-rec-go')?.addEventListener('click', () => {
        closeModal();
        startChallenge(rec.size);
    });
    modalCard.querySelectorAll('.lb-tab').forEach((el) => {
        el.addEventListener('click', () => {
            openChallengeModal(Number(el.getAttribute('data-lb-size')) as ChallengeSize);
        });
    });
    document.getElementById('m-start-tab')?.addEventListener('click', () => {
        closeModal();
        startChallenge(tabSize);
    });
    document.getElementById('m-close')?.addEventListener('click', closeModal);
}

function openSkinsModal(category: 'all' | 'jelly' | 'art' | 'fx' = 'all') {
    const filtered =
        category === 'all' ? JELLY_SKINS : JELLY_SKINS.filter((s) => s.category === category);

    const cards = filtered
        .map((s) => {
            const unlocked = save.unlockedSkins.includes(s.id);
            const active = save.activeSkin === s.id;
            const preview = s.remoteTextureUrl
                ? `<img class="skin-thumb" src="${s.remoteTextureUrl}" alt="${s.name}" />`
                : `<div class="skin-palette-bar">${s.colors
                      .map((c) => `<span style="background:${c}"></span>`)
                      .join('')}</div>`;
            const ctaText = active ? '✓ Equipped' : unlocked ? 'Use Skin' : `🍬 ${s.cost}`;
            return `
              <div class="skin-card ${active ? 'active' : ''}" data-skin="${s.id}">
                <div class="skin-top-row">
                  ${preview}
                  <span class="skin-tag">${s.tag}</span>
                </div>
                <div class="skin-name">${s.name}</div>
                <div class="skin-sub">${s.subtitle}</div>
                <div class="skin-cta ${unlocked ? '' : 'locked'}">${ctaText}</div>
              </div>
            `;
        })
        .join('');

    const cats: Array<{ id: 'all' | 'jelly' | 'art' | 'fx'; label: string }> = [
        { id: 'all', label: 'All (10)' },
        { id: 'jelly', label: 'Jelly' },
        { id: 'art', label: 'AI Art' },
        { id: 'fx', label: 'FX' },
    ];
    const catTabs = cats
        .map(
            (c) =>
                `<button class="lb-tab ${category === c.id ? 'active' : ''}" data-cat="${c.id}">${c.label}</button>`,
        )
        .join('');

    openModal(`
      <div class="shop-header">
        <div class="modal-title" style="margin:0;">Jelly Boutique</div>
        <div style="display:flex;align-items:center;gap:6px;">
          <button class="shop-balance" id="shop-ad-btn">🍬 ${save.coins} · +30 🎬</button>
          <button class="modal-close-x" id="m-close" aria-label="Close">✕</button>
        </div>
      </div>
      <div class="lb-tabs" style="grid-template-columns:repeat(4,1fr);margin:6px 0 10px;">${catTabs}</div>
      <div class="skin-grid">${cards}</div>
    `);

    document.getElementById('shop-ad-btn')?.addEventListener('click', () => {
        save.coins += 30;
        persistSaveData(save);
        updateHUD();
        JellyAudio.playSolveChord();
        openSkinsModal(category);
        showToast('Rewarded Ad complete! +30 🍬');
    });
    modalCard.querySelectorAll('[data-cat]').forEach((el) => {
        el.addEventListener('click', () => {
            openSkinsModal(el.getAttribute('data-cat') as 'all' | 'jelly' | 'art' | 'fx');
        });
    });
    modalCard.querySelectorAll('.skin-card').forEach((el) => {
        el.addEventListener('click', () => {
            const id = el.getAttribute('data-skin')!;
            const skin = getSkinById(id);
            if (!save.unlockedSkins.includes(id)) {
                if (save.coins < skin.cost) {
                    showToast(`Need ${skin.cost} 🍬 to unlock`);
                    return;
                }
                save.coins -= skin.cost;
                save.unlockedSkins.push(id);
                JellyAudio.playSolveChord();
            }
            save.activeSkin = id;
            persistSaveData(save);
            renderer.applySkin(skin);
            updateHUD();
            openSkinsModal(category);
            showToast(`Equipped: ${skin.name}`);
        });
    });
    document.getElementById('m-close')?.addEventListener('click', closeModal);
}

function openLevelsModal() {
    let cells = '';
    for (let i = 1; i <= TOTAL_LEVELS; i++) {
        const unlocked = i <= save.unlockedLevel;
        const stars = save.levelStars[i] ?? 0;
        cells += `<button class="lvl-cell ${unlocked ? '' : 'locked'}" data-lvl="${i}">
          ${i}<span class="lvl-stars">${unlocked ? '★'.repeat(stars) || '·' : '🔒'}</span>
        </button>`;
    }
    openModal(`
      <div class="modal-title">Select Level (1–30)</div>
      <div class="level-grid">${cells}</div>
      <button class="modal-btn secondary" id="m-close">Close</button>
    `);
    modalCard.querySelectorAll('.lvl-cell').forEach((el) => {
        el.addEventListener('click', () => {
            const id = Number(el.getAttribute('data-lvl'));
            if (id <= save.unlockedLevel) {
                closeModal();
                startLevel(id);
            }
        });
    });
    document.getElementById('m-close')?.addEventListener('click', closeModal);
}

function openMenuModal() {
    if (!paused && runStartMs !== null && !solved) {
        elapsedMs = performance.now() - runStartMs;
        paused = true;
    }
    openModal(`
      <div class="modal-title">Paused</div>
      <button class="modal-btn primary" id="m-go-home">🏠 Home</button>
      <button class="modal-btn secondary" id="m-retry">↻ Restart Level</button>
      <button class="modal-btn secondary" id="m-mute">${save.muted ? '🔇 Sound: Off' : '🔊 Sound: On'}</button>
      <button class="modal-btn secondary" id="m-close">▶ Resume</button>
    `);
    document.getElementById('m-go-home')?.addEventListener('click', () => {
        paused = false;
        closeModal();
        function autoDailyCheckIn() {
    const today = todayDateKey();
    if (save.lastCheckInDate === today) return;
    save.lastCheckInDate = today;
    save.checkInStreak += 1;
    const reward = getCheckInReward(save.checkInStreak);
    save.coins += reward.coins;
    persistSaveData(save);
    updateHUD();
    showToast(`Welcome back! ${reward.label}`);
}

showHome();
autoDailyCheckIn();
    });
    document.getElementById('m-retry')?.addEventListener('click', () => {
        paused = false;
        closeModal();
        if (playMode === 'level') startLevel(level.id);
        else if (playMode === 'daily') startDaily();
        else if (playMode === 'challenge') startChallenge(challengeSize);
        else startFree(freeSize);
    });
    document.getElementById('m-mute')?.addEventListener('click', () => {
        save.muted = !save.muted;
        JellyAudio.setMuted(save.muted);
        persistSaveData(save);
        openMenuModal();
    });
    document.getElementById('m-close')?.addEventListener('click', () => {
        if (paused && runStartMs !== null) {
            runStartMs = performance.now() - elapsedMs;
        }
        paused = false;
        closeModal();
    });
}

// Button wiring
document.querySelectorAll('[data-nav]').forEach((el) => {
    el.addEventListener('click', () => {
        const nav = el.getAttribute('data-nav');
        if (nav === 'levels') openLevelsModal();
        else if (nav === 'skins') openSkinsModal();
    });
});
document.getElementById('btn-menu')!.addEventListener('click', openMenuModal);
document.getElementById('home-play')!.addEventListener('click', () => startLevel(save.unlockedLevel));
document.getElementById('home-daily')!.addEventListener('click', startDaily);
document.getElementById('home-challenge')!.addEventListener('click', () => openChallengeModal());
document.getElementById('home-skins')!.addEventListener('click', () => openSkinsModal());
let sharedToday = false;
document.getElementById('home-share')!.addEventListener('click', async () => {
    const text = `I reached Level ${save.unlockedLevel} in Jelly Cube 3D! Come beat my speedrun time!`;
    let ok = false;
    if (navigator.share) {
        try {
            await navigator.share({ title: 'Jelly Cube 3D', text, url: location.href });
            ok = true;
        } catch {
            // user cancelled or unsupported
        }
    }
    if (!ok) {
        try {
            await navigator.clipboard.writeText(`${text} ${location.href}`);
            ok = true;
        } catch {
            ok = false;
        }
    }
    if (ok && !sharedToday) {
        sharedToday = true;
        save.coins += 15;
        persistSaveData(save);
        updateHUD();
        JellyAudio.playSolveChord();
        showToast('Shared! +15 🍬');
    } else if (ok) {
        showToast('Share link copied!');
    }
});
document.getElementById('home-rate')!.addEventListener('click', () => {
    const ua = navigator.userAgent || '';
    if (/iPhone|iPad|iPod/i.test(ua)) {
        // Native iOS uses SKStoreReviewController via AdMobBridge.requestReview
        showToast('Opening App Store Review...');
    } else if (/Android/i.test(ua)) {
        // Native Android uses Google Play store intent via AdMobBridge.requestReview
        showToast('Opening Google Play Review...');
    } else {
        openModal(`
          <div class="shop-header">
            <div class="modal-title" style="margin:0;">Rate Jelly Cube 3D</div>
            <button class="modal-close-x" id="m-close">✕</button>
          </div>
          <p style="color:#664e76;font-size:14px;line-height:1.5;">
            On iOS & Android builds, this opens the native <strong>App Store / Google Play</strong> review sheet directly.
          </p>
          <button class="modal-btn primary" id="m-close-ok">Got it</button>
        `);
        document.getElementById('m-close')?.addEventListener('click', closeModal);
        document.getElementById('m-close-ok')?.addEventListener('click', closeModal);
    }
});
document.getElementById('btn-privacy')!.addEventListener('click', () => {
    openModal(`
      <div class="shop-header">
        <div class="modal-title" style="margin:0;">Privacy Policy</div>
        <button class="modal-close-x" id="m-close">✕</button>
      </div>
      <p style="color:#664e76;font-size:13px;line-height:1.6;text-align:left;">
        Jelly Cube 3D stores your level progress, skins, and sugar balance locally on your device.
        Speedrun leaderboard submissions send only your nickname, country code, time, and move count to Cloudflare D1.
        Ads are served by Google AdMob in accordance with App Tracking Transparency (ATT) and GDPR consent.<br/><br/>
        Support: <strong>support@zhongbei.tech</strong>
      </p>
      <a class="modal-btn primary" style="display:block;text-decoration:none;" href="https://auth.zhongbei.tech/legal/privacy?app=jellycube3d&locale=en-US" target="_blank" rel="noopener">View Full Hosted Policy ↗</a>
    `);
    document.getElementById('m-close')?.addEventListener('click', closeModal);
});
document.getElementById('btn-terms')!.addEventListener('click', () => {
    openModal(`
      <div class="shop-header">
        <div class="modal-title" style="margin:0;">Terms & Support</div>
        <button class="modal-close-x" id="m-close">✕</button>
      </div>
      <p style="color:#664e76;font-size:13px;line-height:1.6;text-align:left;">
        Jelly Cube 3D (<code>tech.zhongbei.jellycube3d</code>) is provided for personal entertainment. Virtual Sugar coins and unlocked skins have no real-world monetary value.<br/><br/>
        Contact: <strong>support@zhongbei.tech</strong>
      </p>
      <a class="modal-btn primary" style="display:block;text-decoration:none;" href="https://auth.zhongbei.tech/legal/privacy?app=jellycube3d&locale=en-US" target="_blank" rel="noopener">Legal & Privacy Portal ↗</a>
    `);
    document.getElementById('m-close')?.addEventListener('click', closeModal);
});
document.getElementById('home-ad-coins')!.addEventListener('click', () => {
    save.coins += 30;
    persistSaveData(save);
    updateHUD();
    JellyAudio.playSolveChord();
    showToast('Rewarded Ad complete! +30 🍬');
});
document.getElementById('btn-auto-solve')!.addEventListener('click', () => {
    if (solved || autoSolving) return;
    const tutorialCost = 60;
    const canAfford = save.coins >= tutorialCost;
    const runTutorial = () => {
        closeModal();
        assistedSolve = true;
        autoSolving = true;
        showToast('Tutorial running (unranked)');
        const stepTimer = window.setInterval(() => {
            if (!autoSolving || solved) {
                window.clearInterval(stepTimer);
                return;
            }
            const next = cube.hintNextMove();
            if (!next) {
                autoSolving = false;
                window.clearInterval(stepTimer);
                return;
            }
            commitMove(next, -next.quarterTurns * 90);
        }, 360);
    };

    openModal(`
      <div class="modal-title">🎬 Solve Tutorial</div>
      <p style="color:#664e76;font-size:14px;line-height:1.6;">
        See a <strong>step-by-step solve tutorial</strong>.<br/>
        Note: Tutorial runs <strong>do not count</strong> toward stars or global rankings.
      </p>
      ${canAfford ? `<button class="modal-btn primary" id="m-tut-coins">Use ${tutorialCost} 🍬 (Instant)</button>` : ''}
      <button class="modal-btn gold" id="m-watch-solve">Watch Ad (Free Tutorial)</button>
      <button class="modal-btn secondary" id="m-close">Cancel</button>
    `);
    document.getElementById('m-tut-coins')?.addEventListener('click', () => {
        save.coins -= tutorialCost;
        persistSaveData(save);
        updateHUD();
        runTutorial();
    });
    document.getElementById('m-watch-solve')?.addEventListener('click', runTutorial);
    document.getElementById('m-close')?.addEventListener('click', closeModal);
});
document.getElementById('btn-undo')!.addEventListener('click', () => {
    if (solved) return;
    const inv = cube.undo();
    if (!inv) return showToast('Nothing to undo');
    renderer.animateMove(inv, -inv.quarterTurns * 90);
    JellyAudio.playSnap(-1);
    updateHUD();
});
document.getElementById('btn-hint')!.addEventListener('click', () => {
    if (solved) return;
    const hint = cube.hintNextMove();
    if (!hint) return;
    const hintCost = 20;
    const canAfford = save.coins >= hintCost;
    const triggerHint = () => {
        closeModal();
        renderer.playHintMotion(hint);
        JellyAudio.playPoke();
        showToast('Follow the highlighted slice direction');
    };
    openModal(`
      <div class="modal-title">💡 Need a Hint?</div>
      <p style="color:#664e76;font-size:14px;">Highlights the next slice & rotation direction without hurting your score.</p>
      ${canAfford ? `<button class="modal-btn primary" id="m-hint-coins">Use ${hintCost} 🍬 (Instant)</button>` : ''}
      <button class="modal-btn gold" id="m-hint-ad">Watch Ad (Free Hint)</button>
      <button class="modal-btn secondary" id="m-close">Cancel</button>
    `);
    document.getElementById('m-hint-coins')?.addEventListener('click', () => {
        save.coins -= hintCost;
        persistSaveData(save);
        updateHUD();
        triggerHint();
    });
    document.getElementById('m-hint-ad')?.addEventListener('click', triggerHint);
    document.getElementById('m-close')?.addEventListener('click', closeModal);
});

// Pointer 3D interaction
let dragState: {
    startX: number;
    startY: number;
    hit: WebHit;
    axis: number;
    coord: number;
    dir: [number, number];
    angle: number;
} | null = null;
let orbiting = false;
let lastX = 0, lastY = 0;

canvas.addEventListener('pointerdown', (e) => {
    lastX = e.clientX;
    lastY = e.clientY;
    if (onHome || autoSolving) {
        orbiting = true;
        return;
    }
    const hit = renderer.pickCubelet(e.clientX, e.clientY);
    if (hit && !solved) {
        dragState = {
            startX: e.clientX,
            startY: e.clientY,
            hit,
            axis: -1,
            coord: 0,
            dir: [1, 0],
            angle: 0,
        };
        return;
    }
    orbiting = true;
});

window.addEventListener('pointermove', (e) => {
    const dx = e.clientX - lastX;
    const dy = e.clientY - lastY;
    lastX = e.clientX;
    lastY = e.clientY;

    if (orbiting) {
        renderer.orbitBy(dx, -dy);
        return;
    }
    if (!dragState) return;
    const tx = e.clientX - dragState.startX;
    const ty = e.clientY - dragState.startY;
    if (dragState.axis < 0) {
        if (Math.hypot(tx, ty) < 8) return;
        const n = dragState.hit.worldNormal;
        const nAxis = Math.abs(n[0]) > 0.5 ? 0 : Math.abs(n[1]) > 0.5 ? 1 : 2;
        const oScreen = renderer.worldToScreen(dragState.hit.worldPoint);
        let bestAxis = 0, bestScore = -1;
        let bestDir: [number, number] = [1, 0];
        for (let a = 0; a < 3; a++) {
            if (a === nAxis) continue;
            const av: [number, number, number] = [a === 0 ? 1 : 0, a === 1 ? 1 : 0, a === 2 ? 1 : 0];
            const tang: [number, number, number] = [
                av[1] * n[2] - av[2] * n[1],
                av[2] * n[0] - av[0] * n[2],
                av[0] * n[1] - av[1] * n[0],
            ];
            const tip = renderer.worldToScreen([
                dragState.hit.worldPoint[0] + tang[0] * 0.5,
                dragState.hit.worldPoint[1] + tang[1] * 0.5,
                dragState.hit.worldPoint[2] + tang[2] * 0.5,
            ]);
            const sx = tip[0] - oScreen[0], sy = tip[1] - oScreen[1];
            const len = Math.hypot(sx, sy) || 1;
            const ux = sx / len, uy = sy / len;
            const dot = Math.abs(tx * ux + ty * uy);
            if (dot > bestScore) {
                bestScore = dot;
                bestAxis = a;
                bestDir = [ux, uy];
            }
        }
        dragState.axis = bestAxis;
        dragState.coord = dragState.hit.cubie.pos.at(bestAxis);
        dragState.dir = bestDir;
    }
    const proj = tx * dragState.dir[0] + ty * dragState.dir[1];
    dragState.angle = Math.max(-135, Math.min(135, proj * 0.48));
    renderer.setInteractiveTurn(dragState.axis, dragState.coord, dragState.angle);
});

window.addEventListener('pointerup', () => {
    orbiting = false;
    if (!dragState) return;
    const d = dragState;
    dragState = null;
    renderer.clearInteractiveTurn();
    if (d.axis < 0) return;
    const q = Math.round(d.angle / 90);
    if (q !== 0) {
        commitMove({ axis: d.axis, coordinates: [d.coord], quarterTurns: q }, d.angle - q * 90);
    } else {
        renderer.animateMove({ axis: d.axis, coordinates: [d.coord], quarterTurns: 0 }, d.angle);
    }
});

// Expose test hook for automated playtest
(window as unknown as Record<string, unknown>).__jellyPlaytest = {
    startLevel,
    startDaily,
    startFree,
    openSkinsModal,
    openLevelsModal,
    closeModal,
    unlockSkin: (id: string) => {
        save.coins = Math.max(save.coins, 500);
        if (!save.unlockedSkins.includes(id)) save.unlockedSkins.push(id);
        save.activeSkin = id;
        persistSaveData(save);
        renderer.applySkin(getSkinById(id));
        updateHUD();
    },
    solveOneStep: () => {
        const h = cube.hintNextMove();
        if (h) commitMove(h, 0);
    },
    showSolvedWithSkin: (id: string) => {
        enterGame();
        cube = new JellyCube(3);
        cube.reset();
        solved = false;
        renderer.bindCube(cube);
        save.activeSkin = id;
        renderer.applySkin(getSkinById(id));
        updateHUD();
    },
    getState: () => ({
        playMode,
        levelId: level.id,
        moves: cube.playerMoveCount,
        solved,
        skin: save.activeSkin,
    }),
};

function autoDailyCheckIn() {
    const today = todayDateKey();
    if (save.lastCheckInDate === today) return;
    save.lastCheckInDate = today;
    save.checkInStreak += 1;
    const reward = getCheckInReward(save.checkInStreak);
    save.coins += reward.coins;
    persistSaveData(save);
    updateHUD();
    showToast(`Welcome back! ${reward.label}`);
}

showHome();
autoDailyCheckIn();
let lastTime = performance.now();
function loop(now: number) {
    const dt = (now - lastTime) / 1000;
    lastTime = now;
    if (onHome && !orbiting) {
        renderer.targetYaw += dt * 16;
    }
    if (!onHome && runStartMs !== null && !solved) {
        updateHUD();
    }
    renderer.render(dt);
    requestAnimationFrame(loop);
}
requestAnimationFrame(loop);
