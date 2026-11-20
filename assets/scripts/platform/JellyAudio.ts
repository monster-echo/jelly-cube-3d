// Jelly Cube 3D — Zero-Asset Procedural ASMR Jelly Audio Synthesizer

class JellyAudioImpl {
    private _ctx: AudioContext | null = null;
    private _muted = false;

    setMuted(muted: boolean): void {
        this._muted = muted;
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
