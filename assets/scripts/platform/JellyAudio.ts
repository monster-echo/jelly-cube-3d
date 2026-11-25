// Jelly Cube 3D — procedural Web Audio on desktop, bundled clips on native.
// The native runtime has no AudioContext, so iOS/Android play the WAVs in
// assets/resources/audio through cc.AudioSource instead.

import { AudioClip, AudioSource, director, Node, resources, sys } from 'cc';
import { trace } from './JellyTrace';

class JellyAudioImpl {
    private _ctx: AudioContext | null = null;
    private _muted = false;
    private _bgm: AudioSource | null = null;
    private _pool: AudioSource[] = [];
    private _poolIndex = 0;
    private _lastSnapAt = 0;
    private _clips = new Map<string, AudioClip>();
    private _loading = new Set<string>();
    private _ready = false;

    private get _native(): boolean {
        return sys.isNative;
    }

    /** Native: preload clips and start the loop. Web: no-op. */
    init(): void {
        if (!this._native || this._ready) return;
        this._ready = true;
        this._ensureSources();
        for (const name of ['snap', 'poke', 'bounce', 'solve', 'bgm']) this._load(name);
        this._startMusic();
    }

    private _ensureSources(): void {
        if (this._bgm) return;
        const scene = director.getScene();
        if (!scene) return;
        const node = new Node('JellyAudio');
        node.parent = scene;
        this._bgm = node.addComponent(AudioSource);
        this._bgm.loop = true;
        this._bgm.volume = 0.32;
        // Small pool: reuse players instead of creating one per shot, which
        // is what made rapid snaps risky on native.
        for (let i = 0; i < 3; i++) {
            const sfxNode = new Node(`Sfx${i}`);
            sfxNode.parent = node;
            this._pool.push(sfxNode.addComponent(AudioSource));
        }
    }

    private _load(name: string): void {
        if (this._clips.has(name) || this._loading.has(name)) return;
        this._loading.add(name);
        resources.load(`audio/${name}`, AudioClip, (err, clip) => {
            this._loading.delete(name);
            if (err || !clip) return;
            this._clips.set(name, clip);
            if (name === 'bgm') this._startMusic();
        });
    }

    private _play(name: string, volume: number): void {
        if (this._muted || !this._native) return;
        this._ensureSources();
        const clip = this._clips.get(name);
        if (!clip) {
            this._load(name);
            return;
        }
        trace(`audio:${name}`);
        const source = this._pool[this._poolIndex % this._pool.length];
        if (!source) return;
        this._poolIndex++;
        source.stop();
        source.clip = clip;
        source.volume = volume;
        source.play();
    }

    private _startMusic(): void {
        if (!this._native || this._muted) return;
        this._ensureSources();
        const clip = this._clips.get('bgm');
        if (!clip) {
            this._load('bgm');
            return;
        }
        if (this._bgm && !this._bgm.playing) {
            this._bgm.clip = clip;
            this._bgm.play();
        }
    }

    setMuted(muted: boolean): void {
        this._muted = muted;
        if (!this._native || !this._bgm) return;
        if (muted) this._bgm.stop();
        else this._startMusic();
    }

    private _ensureCtx(): AudioContext | null {
        if (this._muted) return null;
        if (typeof globalThis === 'undefined') return null;
        const AudioCtx =
            (globalThis as unknown as { AudioContext?: typeof AudioContext }).AudioContext ??
            (globalThis as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
        if (!AudioCtx) return null;
        if (!this._ctx) {
            this._ctx = new AudioCtx();
        }
        if (this._ctx.state === 'suspended') {
            this._ctx.resume().catch(() => {});
        }
        return this._ctx;
    }

    /** Crisp rubbery snap when a slice locks into place. */
    playSnap(pitchOffset = 0): void {
        if (this._native) {
            const now = Date.now();
            if (now - this._lastSnapAt < 80) return;
            this._lastSnapAt = now;
            this._play('snap', 0.5);
            return;
        }
        const ctx = this._ensureCtx();
        if (!ctx) return;
        const now = ctx.currentTime;
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.type = 'triangle';
        const base = 260 + pitchOffset * 28;
        osc.frequency.setValueAtTime(base, now);
        osc.frequency.exponentialRampToValueAtTime(base * 1.65, now + 0.045);
        osc.frequency.exponentialRampToValueAtTime(base * 0.85, now + 0.11);

        gain.gain.setValueAtTime(0.001, now);
        gain.gain.linearRampToValueAtTime(0.18, now + 0.012);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.12);

        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.start(now);
        osc.stop(now + 0.13);
    }

    /** Squishy wet pop when poking a jelly cubelet. */
    playPoke(): void {
        if (this._native) {
            this._play('poke', 0.5);
            return;
        }
        const ctx = this._ensureCtx();
        if (!ctx) return;
        const now = ctx.currentTime;
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.type = 'sine';
        osc.frequency.setValueAtTime(190, now);
        osc.frequency.exponentialRampToValueAtTime(420, now + 0.06);
        osc.frequency.exponentialRampToValueAtTime(150, now + 0.14);

        gain.gain.setValueAtTime(0.001, now);
        gain.gain.linearRampToValueAtTime(0.22, now + 0.015);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.15);

        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.start(now);
        osc.stop(now + 0.16);
    }

    /** Bouncy thud when dropping the jelly cube onto the plate. */
    playBounce(): void {
        if (this._native) {
            this._play('bounce', 0.55);
            return;
        }
        const ctx = this._ensureCtx();
        if (!ctx) return;
        const now = ctx.currentTime;
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.type = 'sine';
        osc.frequency.setValueAtTime(135, now);
        osc.frequency.exponentialRampToValueAtTime(62, now + 0.16);

        gain.gain.setValueAtTime(0.26, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.18);

        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.start(now);
        osc.stop(now + 0.19);
    }

    /** Bright celebratory chord when a level is solved. */
    playSolveChord(): void {
        if (this._native) {
            this._play('solve', 0.55);
            return;
        }
        const ctx = this._ensureCtx();
        if (!ctx) return;
        const notes = [523.25, 659.25, 783.99, 1046.5];
        notes.forEach((freq, idx) => {
            const now = ctx.currentTime + idx * 0.065;
            const osc = ctx.createOscillator();
            const gain = ctx.createGain();
            osc.type = 'sine';
            osc.frequency.setValueAtTime(freq, now);
            gain.gain.setValueAtTime(0.001, now);
            gain.gain.linearRampToValueAtTime(0.14, now + 0.02);
            gain.gain.exponentialRampToValueAtTime(0.001, now + 0.45);
            osc.connect(gain);
            gain.connect(ctx.destination);
            osc.start(now);
            osc.stop(now + 0.46);
        });
    }
}

export const JellyAudio = new JellyAudioImpl();
