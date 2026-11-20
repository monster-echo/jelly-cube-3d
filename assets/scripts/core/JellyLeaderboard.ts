// Jelly Cube 3D — Speed Challenge Recommendations, Daily Streak Rewards & Cloudflare Global Leaderboard

import { SizeRecord } from './JellyStorage';

export const CHALLENGE_SIZES = [3, 4, 5, 9, 10] as const;
export type ChallengeSize = (typeof CHALLENGE_SIZES)[number];

/**
 * Set this to your deployed Cloudflare Worker URL, e.g.:
 *   https://jelly-cube-3d-leaderboard.<your-subdomain>.workers.dev
 * When empty, the game seamlessly uses the local benchmark leaderboard.
 */
export const CLOUDFLARE_LB_URL = 'https://jelly-cube-3d-leaderboard.rwecho.workers.dev';

export interface LeaderboardEntry {
    rank: number;
    name: string;
    region: string;
    timeMs: number;
    moves: number;
    isPlayer?: boolean;
}

export interface ChallengeRecommendation {
    size: ChallengeSize;
    title: string;
    badge: string;
    scrambleSteps: number;
}

const GLOBAL_BASELINES: Record<ChallengeSize, Array<Omit<LeaderboardEntry, 'rank'>>> = {
    3: [
        { name: 'Feliks_Z', region: 'AU', timeMs: 5420, moves: 18 },
        { name: 'Yiheng_W', region: 'CN', timeMs: 5890, moves: 19 },
        { name: 'MaxPark', region: 'US', timeMs: 6340, moves: 21 },
        { name: 'Tymon_K', region: 'PL', timeMs: 7120, moves: 22 },
        { name: 'Ruihang_X', region: 'CN', timeMs: 8450, moves: 24 },
        { name: 'Sora_J', region: 'JP', timeMs: 11200, moves: 28 },
        { name: 'Lucas_M', region: 'FR', timeMs: 15800, moves: 34 },
        { name: 'Mina_K', region: 'KR', timeMs: 22400, moves: 41 },
    ],
    4: [
        { name: 'MaxPark', region: 'US', timeMs: 18420, moves: 44 },
        { name: 'Sebastian_W', region: 'DE', timeMs: 20150, moves: 48 },
        { name: 'Yiheng_W', region: 'CN', timeMs: 23600, moves: 52 },
        { name: 'Tymon_K', region: 'PL', timeMs: 27800, moves: 56 },
        { name: 'Aoi_T', region: 'JP', timeMs: 36400, moves: 64 },
        { name: 'Noah_B', region: 'CA', timeMs: 49500, moves: 72 },
        { name: 'Chloe_L', region: 'SG', timeMs: 68200, moves: 85 },
    ],
    5: [
        { name: 'MaxPark', region: 'US', timeMs: 36800, moves: 78 },
        { name: 'Tymon_K', region: 'PL', timeMs: 41200, moves: 82 },
        { name: 'Nahm_S', region: 'KR', timeMs: 47900, moves: 90 },
        { name: 'Kevin_H', region: 'US', timeMs: 59300, moves: 102 },
        { name: 'Yuki_S', region: 'JP', timeMs: 84100, moves: 120 },
        { name: 'Liam_O', region: 'UK', timeMs: 118500, moves: 145 },
    ],
    9: [
        { name: 'Kevin_H', region: 'US', timeMs: 214000, moves: 260 },
        { name: 'Anyu_C', region: 'CN', timeMs: 248500, moves: 285 },
        { name: 'Victor_R', region: 'BR', timeMs: 312000, moves: 320 },
        { name: 'Haruto_N', region: 'JP', timeMs: 389000, moves: 360 },
        { name: 'Elena_V', region: 'ES', timeMs: 495000, moves: 410 },
    ],
    10: [
        { name: 'Anyu_C', region: 'CN', timeMs: 286000, moves: 340 },
        { name: 'Kevin_H', region: 'US', timeMs: 318000, moves: 375 },
        { name: 'Sora_J', region: 'JP', timeMs: 405000, moves: 430 },
        { name: 'Marco_T', region: 'IT', timeMs: 512000, moves: 490 },
        { name: 'Leo_D', region: 'FR', timeMs: 640000, moves: 560 },
    ],
};

export function getRecommendedChallenge(unlockedLevel: number): ChallengeRecommendation {
    if (unlockedLevel <= 8) {
        return { size: 3, title: '3×3 Speed Sprint', badge: 'PICK FOR YOU', scrambleSteps: 10 };
    }
    if (unlockedLevel <= 18) {
        return { size: 4, title: '4×4 Pro Challenge', badge: 'TRENDING', scrambleSteps: 14 };
    }
    if (unlockedLevel <= 24) {
        return { size: 5, title: '5×5 Master Trial', badge: 'HARDCORE', scrambleSteps: 18 };
    }
    if (unlockedLevel <= 28) {
        return { size: 9, title: '9×9 Extreme Jelly', badge: 'ELITE', scrambleSteps: 22 };
    }
    return { size: 10, title: '10×10 Ultimate Boss', badge: 'LEGEND', scrambleSteps: 26 };
}

export function scrambleStepsForChallenge(size: ChallengeSize): number {
    if (size === 3) return 10;
    if (size === 4) return 14;
    if (size === 5) return 18;
    if (size === 9) return 22;
    return 26;
}

export function getDailyStreakReward(nextStreak: number): {
    coins: number;
    unlockSkinId?: string;
    label: string;
} {
    if (nextStreak >= 7 && nextStreak % 7 === 0) {
        return {
            coins: 260,
            unlockSkinId: 'nebula',
            label: `${nextStreak}-Day Streak! Unlocked Nebula Glow + 260 Sugar`,
        };
    }
    if (nextStreak >= 5) return { coins: 180, label: `${nextStreak}-Day Streak! +180 Sugar` };
    if (nextStreak >= 3) return { coins: 120, label: `${nextStreak}-Day Streak! +120 Sugar` };
    if (nextStreak === 2) return { coins: 80, label: '2-Day Streak! +80 Sugar' };
    return { coins: 60, label: 'Daily Solved! +60 Sugar' };
}

export function getCheckInReward(nextStreak: number): { coins: number; label: string } {
    const table = [30, 40, 50, 60, 80, 90, 120];
    const idx = Math.min(table.length - 1, Math.max(0, nextStreak - 1));
    const coins = table[idx];
    return { coins, label: `Day ${nextStreak} Check-in! +${coins} 🍬` };
}

export function formatDurationMs(ms: number): string {
    const clamped = Math.max(0, Math.floor(ms));
    const totalSec = Math.floor(clamped / 1000);
    const mins = Math.floor(totalSec / 60);
    const secs = totalSec % 60;
    const tenths = Math.floor((clamped % 1000) / 100);
    return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}.${tenths}`;
}

export function getGlobalLeaderboard(
    size: ChallengeSize,
    playerName: string,
    playerRecord?: SizeRecord,
): { entries: LeaderboardEntry[]; playerRank: number | null; beatPercent: number; isLive: boolean } {
    const list: Array<Omit<LeaderboardEntry, 'rank'>> = GLOBAL_BASELINES[size].map((e) => ({ ...e }));

    if (playerRecord) {
        list.push({
            name: `${playerName} (You)`,
            region: 'CN',
            timeMs: playerRecord.timeMs,
            moves: playerRecord.moves,
            isPlayer: true,
        });
    }

    list.sort((a, b) => a.timeMs - b.timeMs || a.moves - b.moves);
    const entries: LeaderboardEntry[] = list.map((item, idx) => ({ ...item, rank: idx + 1 }));

    const playerEntry = entries.find((e) => e.isPlayer);
    const playerRank = playerEntry ? playerEntry.rank : null;
    const beatPercent =
        playerRank !== null
            ? Math.max(5, Math.round(((entries.length - playerRank) / Math.max(1, entries.length - 1)) * 99))
            : 0;

    return { entries, playerRank, beatPercent, isLive: false };
}

/** Fetches live global leaderboard from Cloudflare Worker + D1 when configured. */
export async function fetchGlobalLeaderboard(
    size: ChallengeSize,
    playerId: string,
    playerName: string,
    localRecord?: SizeRecord,
): Promise<{ entries: LeaderboardEntry[]; playerRank: number | null; beatPercent: number; isLive: boolean }> {
    if (!CLOUDFLARE_LB_URL) {
        return getGlobalLeaderboard(size, playerName, localRecord);
    }
    try {
        const res = await fetch(`${CLOUDFLARE_LB_URL}/api/leaderboard?size=${size}`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = (await res.json()) as {
            entries?: Array<{ player_id: string; name: string; region: string; time_ms: number; moves: number }>;
        };
        const raw = data.entries ?? [];
        const entries: LeaderboardEntry[] = raw.map((r, idx) => ({
            rank: idx + 1,
            name: r.player_id === playerId ? `${r.name} (You)` : r.name,
            region: r.region,
            timeMs: r.time_ms,
            moves: r.moves,
            isPlayer: r.player_id === playerId,
        }));
        const me = entries.find((e) => e.isPlayer);
        const playerRank = me ? me.rank : null;
        const beatPercent =
            playerRank !== null
                ? Math.max(5, Math.round(((entries.length - playerRank) / Math.max(1, entries.length - 1)) * 99))
                : 0;
        return { entries, playerRank, beatPercent, isLive: true };
    } catch {
        return getGlobalLeaderboard(size, playerName, localRecord);
    }
}

/** Submits player's PB to Cloudflare Worker + D1 when configured. */
export async function submitGlobalScore(
    size: ChallengeSize,
    playerId: string,
    playerName: string,
    record: SizeRecord,
): Promise<boolean> {
    if (!CLOUDFLARE_LB_URL) return false;
    try {
        const res = await fetch(`${CLOUDFLARE_LB_URL}/api/score`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                size,
                playerId,
                name: playerName,
                timeMs: record.timeMs,
                moves: record.moves,
            }),
        });
        return res.ok;
    } catch {
        return false;
    }
}
