// Jelly Cube 3D — Cross-platform Save & Progress Persistence.

import { sys } from 'cc';

export interface SizeRecord {
    timeMs: number;
    moves: number;
    date: string;
}

export interface JellySaveData {
    version: number;
    unlockedLevel: number;
    levelStars: Record<number, number>;
    coins: number;
    unlockedSkins: string[];
    activeSkin: string;
    dailyCompletedDate: string;
    dailyStreak: number;
    lastCheckInDate: string;
    checkInStreak: number;
    muted: boolean;
    haptics: boolean;
    bestRecords: Record<number, SizeRecord>;
    playerId: string;
    playerName: string;
}

const STORAGE_KEY = 'jelly_cube_3d_save_v1';

function makePlayerId(): string {
    return `jc_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;
}

export function defaultSaveData(): JellySaveData {
    return {
        version: 1,
        unlockedLevel: 1,
        levelStars: {},
        coins: 120,
        unlockedSkins: ['classic'],
        activeSkin: 'classic',
        dailyCompletedDate: '',
        dailyStreak: 0,
        lastCheckInDate: '',
        checkInStreak: 0,
        muted: false,
        haptics: true,
        bestRecords: {},
        playerId: makePlayerId(),
        playerName: 'Player',
    };
}

let memoryFallback: string | null = null;

// On native there is no window.localStorage; cc.sys.localStorage is the
// platform-backed store, so progress survives relaunches on iOS/Android too.
function storage(): Storage | null {
    try {
        if (sys && sys.localStorage) return sys.localStorage;
    } catch {
        // Ignore
    }
    try {
        if (typeof globalThis !== 'undefined' && 'localStorage' in globalThis && globalThis.localStorage) {
            return globalThis.localStorage as Storage;
        }
    } catch {
        // Ignore
    }
    return null;
}

function readRaw(): string | null {
    const s = storage();
    if (s) {
        try {
            return s.getItem(STORAGE_KEY);
        } catch {
            // Ignore restricted storage environments
        }
    }
    return memoryFallback;
}

function writeRaw(json: string): void {
    memoryFallback = json;
    const s = storage();
    if (!s) return;
    try {
        s.setItem(STORAGE_KEY, json);
    } catch {
        // Ignore
    }
}

export function loadSaveData(): JellySaveData {
    const raw = readRaw();
    if (!raw) return defaultSaveData();
    try {
        const parsed = JSON.parse(raw) as Partial<JellySaveData>;
        const base = defaultSaveData();
        return {
            ...base,
            ...parsed,
            levelStars: parsed.levelStars ?? base.levelStars,
            bestRecords: parsed.bestRecords ?? base.bestRecords,
            unlockedSkins: Array.isArray(parsed.unlockedSkins) && parsed.unlockedSkins.length > 0
                ? parsed.unlockedSkins
                : base.unlockedSkins,
        };
    } catch {
        return defaultSaveData();
    }
}

export function persistSaveData(data: JellySaveData): void {
    writeRaw(JSON.stringify(data));
}

export function todayDateKey(now = new Date()): string {
    const y = now.getFullYear();
    const m = String(now.getMonth() + 1).padStart(2, '0');
    const d = String(now.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
}
