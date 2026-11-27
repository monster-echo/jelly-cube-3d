// Jelly Cube 3D — Home / in-game HUD ported from the web build (web/style.css).
// The web DOM/CSS is the design source of truth: same layout, colours, radii,
// type scale and copy. Values below are CSS pixels; they are multiplied by
// this._u (design units per CSS px) so the UI keeps the web proportions.

import {
    _decorator,
    BlockInputEvents,
    Button,
    Color,
    Component,
    Graphics,
    Label,
    Node,
    UITransform,
    view,
    sys,
} from 'cc';
import {
    CHALLENGE_SIZES,
    ChallengeSize,
    fetchGlobalLeaderboard,
    formatDurationMs,
    getGlobalLeaderboard,
    getRecommendedChallenge,
} from '../core/JellyLeaderboard';
import { computeStars, TOTAL_LEVELS } from '../core/JellyLevels';
import { JELLY_SKINS, JellySkinCategory } from '../core/JellySkins';
import { GameUIState, JellyGameController } from './JellyGameController';
import { PlatformBridge } from '../platform/PlatformBridge';
import { trace } from '../platform/JellyTrace';

const { ccclass, property } = _decorator;

type ModalKind =
    | 'none'
    | 'pause'
    | 'win'
    | 'skins'
    | 'levels'
    | 'leaderboard'
    | 'hint'
    | 'tutorial'
    | 'menu';

const PRIVACY_URL = 'https://auth.zhongbei.tech/legal/privacy?app=jellycube3d&locale=en-US';

// web/style.css tokens
const C = {
    bg: '#f7eaff',
    ink: '#34223e',
    ink2: '#644478',
    dark: '#3e2a4e',
    purple: '#7448f5',
    purple2: '#9b6bff',
    card: '#f0e2fa',
    cardSoft: '#f8f0fd',
    gold: '#ffe8a8',
    goldInk: '#824a0a',
    pink: '#ff4f7e',
    orange: '#ff9e22',
    white: '#ffffff',
    line: '#e6d3f5',
    muted: '#7e6590',
    dot: '#8a7599',
};

function hex(value: string, alpha = 255): Color {
    const c = new Color();
    Color.fromHEX(c, value);
    c.a = alpha;
    return c;
}

function lerp(a: number, b: number, t: number): number {
    return a + (b - a) * t;
}

function parseHex(value: string): [number, number, number] {
    const c = hex(value);
    return [c.r, c.g, c.b];
}

@ccclass('JellyHUD')
export class JellyHUD extends Component {
    @property(JellyGameController)
    controller: JellyGameController | null = null;

    private _unsub: (() => void) | null = null;
    private _state: GameUIState | null = null;
    private _modal: ModalKind = 'none';
    private _skinCat: 'all' | JellySkinCategory = 'all';
    private _lbSize: ChallengeSize = 3;
    private _doubleClaimed = false;

    private _homeRoot!: Node;
    private _gameRoot!: Node;
    private _modalRoot!: Node;
    private _toastNode!: Node;
    private _toastLabel!: Label;
    private _toastToken = 0;
    private _lastOnHome: boolean | null = null;
    private _bannerVisible = false;

    private _homeCoins!: Label;
    private _homePlay!: Label;
    private _homeDaily!: Label;
    private _titleLabel!: Label;
    private _subLabel!: Label;
    private _coinsLabel!: Label;

    // layout scale: design units per CSS pixel
    private _u = 1.85;
    private _w = 720;
    private _h = 1280;
    // Notch / Dynamic Island and home-indicator strips, in design units.
    private _insetTop = 0;
    private _insetBottom = 0;

    private _mb: { card: Node; w: number; cursor: number; items: Node[] } | null = null;

    start(): void {
        // The canvas is aligned to the screen during load; read the visible
        // size here so the layout follows the real design resolution.
        const vs = view.getVisibleSize();
        this._w = Math.max(320, vs.width);
        this._h = Math.max(568, vs.height);
        // Design units per logical screen point: keeps the web's CSS-pixel
        // scale on phones and stops the UI from inflating on wide windows.
        const frame = view.getFrameSize();
        const dpr = view.getDevicePixelRatio() || 1;
        const logicalW = Math.max(320, frame.width / Math.max(1, dpr));
        this._u = this._w / logicalW;
        // false: the default symmetric rect mirrors the larger of top/bottom
        // onto the other edge, which would push the dock down for a notch.
        const safe = sys.getSafeAreaRect(false);
        this._insetTop = Math.max(0, this._h - safe.y - safe.height);
        this._insetBottom = Math.max(0, safe.y);
        this._buildLayout();
        // controller is assigned right after addComponent, so subscribe in
        // start (subscribe also pushes the current state immediately).
        if (this.controller) {
            this._unsub = this.controller.subscribe((s) => this._onStateChanged(s));
        }
    }

    onDestroy(): void {
        this._unsub?.();
    }

    update(): void {
        if (this._state && !this._state.onHome && !this._state.solved && this.controller) {
            const tStr = formatDurationMs(this.controller.getCurrentElapsedMs());
            this._setSubLabel(this._state, tStr);
        }
    }

    private _onStateChanged(state: GameUIState): void {
        const wasSolved = this._state?.solved ?? false;
        this._state = state;
        if (state.solved && !wasSolved) {
            this._doubleClaimed = false;
            this._modal = 'win';
        }
        this._refreshHUD();
    }

    // ------------------------------------------------------------ primitives
    private _uNode(parent: Node, name: string, w: number, h: number): Node {
        const n = new Node(name);
        n.layer = this.node.layer;
        n.parent = parent;
        n.addComponent(UITransform).setContentSize(w, h);
        return n;
    }

    private _surface(
        parent: Node,
        name: string,
        w: number,
        h: number,
        r: number,
        top: string,
        bottom?: string,
        shadow = false,
    ): Node {
        const n = this._uNode(parent, name, w, h);
        const u = this._u;
        if (shadow) {
            for (let i = 3; i >= 1; i--) {
                const pad = i * 2.5 * u;
                const sh = this._uNode(n, 'Sh', w + pad * 2, h + pad * 2);
                const sg = sh.addComponent(Graphics);
                const draw = {
                    x: -(w + pad * 2) / 2,
                    y: -(h + pad * 2) / 2 - 3 * u,
                    w: w + pad * 2,
                    h: h + pad * 2,
                    r: r + pad,
                    color: '#48225c',
                    alpha: 7,
                };
                sg.fillColor = hex(draw.color, draw.alpha);
                sg.roundRect(draw.x, draw.y, draw.w, draw.h, draw.r);
                sg.fill();
                (sh as unknown as { __draw?: typeof draw }).__draw = draw;
            }
        }
        // CSS gradients are approximated with their mid tone; the palette and
        // radii stay identical to web/style.css.
        let fill = top;
        if (bottom && bottom !== top) {
            const a = parseHex(top);
            const b = parseHex(bottom);
            fill = `#${[0, 1, 2]
                .map((i) => Math.round((a[i] + b[i]) / 2).toString(16).padStart(2, '0'))
                .join('')}`;
        }
        // Fill lives on its own child so the shadow siblings stay behind it
        // and labels added by callers stay on top.
        const fillNode = this._uNode(n, 'Fill', w, h);
        const g = fillNode.addComponent(Graphics);
        const draw = { x: -w / 2, y: -h / 2, w, h, r, color: fill, alpha: 255 };
        g.fillColor = hex(draw.color, draw.alpha);
        g.roundRect(draw.x, draw.y, draw.w, draw.h, draw.r);
        g.fill();
        (fillNode as unknown as { __draw?: typeof draw }).__draw = draw;
        return n;
    }

    // Cocos native can keep a Graphics mesh stale when its root is activated
    // after the first frame; replaying the stored draw commands fixes it.
    private _redrawGraphics(root: Node): void {
        const stack: Node[] = [root];
        while (stack.length > 0) {
            const node = stack.pop()!;
            const draw = (node as unknown as { __draw?: { x: number; y: number; w: number; h: number; r: number; color: string; alpha: number } }).__draw;
            const gfx = node.getComponent(Graphics);
            if (draw && gfx) {
                gfx.clear();
                gfx.fillColor = hex(draw.color, draw.alpha);
                gfx.roundRect(draw.x, draw.y, draw.w, draw.h, draw.r);
                gfx.fill();
            }
            stack.push(...node.children);
        }
    }

    private _label(
        parent: Node,
        text: string,
        size: number,
        color: Color,
        w: number,
        h: number,
        bold = false,
        align: 'left' | 'center' = 'center',
        singleLine = false,
    ): Label {
        const n = this._uNode(parent, 'Lbl', w, h);
        const lbl = n.addComponent(Label);
        lbl.useSystemFont = true;
        lbl.fontFamily = 'PingFang SC';
        lbl.string = text;
        lbl.fontSize = Math.round(size * this._u);
        lbl.lineHeight = Math.round(size * this._u * 1.3);
        lbl.color = color;
        lbl.isBold = bold;
        lbl.enableWrapText = !singleLine;
        lbl.overflow = singleLine ? Label.Overflow.SHRINK : Label.Overflow.CLAMP;
        lbl.horizontalAlign =
            align === 'left' ? Label.HorizontalAlign.LEFT : Label.HorizontalAlign.CENTER;
        lbl.verticalAlign = Label.VerticalAlign.CENTER;
        return lbl;
    }

    private _textButton(
        parent: Node,
        text: string,
        size: number,
        color: Color,
        onClick: () => void,
        w = 120,
        h = 24,
    ): Node {
        const n = this._uNode(parent, 'TextBtn', w, h);
        const lbl = n.addComponent(Label);
        lbl.useSystemFont = true;
        lbl.fontFamily = 'PingFang SC';
        lbl.string = text;
        lbl.fontSize = Math.round(size * this._u);
        lbl.lineHeight = Math.round(size * this._u * 1.3);
        lbl.color = color;
        lbl.horizontalAlign = Label.HorizontalAlign.CENTER;
        lbl.verticalAlign = Label.VerticalAlign.CENTER;
        const btn = n.addComponent(Button);
        btn.transition = Button.Transition.SCALE;
        btn.zoomScale = 0.94;
        n.on(Button.EventType.CLICK, onClick, this);
        return n;
    }

    private _button(
        parent: Node,
        name: string,
        w: number,
        h: number,
        r: number,
        fill: string,
        text: string,
        textColor: Color,
        fontSize: number,
        onClick: () => void,
        opts: { gradientTo?: string; bold?: boolean; shadow?: boolean } = {},
    ): { node: Node; label: Label } {
        const node = this._surface(parent, name, w, h, r, fill, opts.gradientTo, opts.shadow);
        const label = this._label(
            node,
            text,
            fontSize,
            textColor,
            w - 12 * this._u,
            h,
            opts.bold ?? true,
        );
        // Single-line button captions shrink instead of wrapping.
        label.enableWrapText = false;
        label.overflow = Label.Overflow.SHRINK;
        const btn = node.addComponent(Button);
        btn.transition = Button.Transition.SCALE;
        btn.zoomScale = 0.95;
        node.on(Button.EventType.CLICK, onClick, this);
        return { node, label };
    }

    // ---------------------------------------------------------------- layout
    private _buildLayout(): void {
        this._homeRoot = this._uNode(this.node, 'HomeRoot', this._w, this._h);
        this._gameRoot = this._uNode(this.node, 'GameRoot', this._w, this._h);

        this._buildHome();
        this._buildGameHud();

        this._toastNode = this._uNode(this.node, 'Toast', this._w, 30 * this._u);
        this._toastNode.setPosition(0, this._h / 2 - this._insetTop - 116 * this._u, 0);
        const toastBg = this._surface(
            this._toastNode,
            'ToastBg',
            240 * this._u,
            30 * this._u,
            15 * this._u,
            '#ffffff',
            undefined,
            true,
        );
        toastBg.setPosition(0, 0, 0);
        this._toastLabel = this._label(
            toastBg,
            '',
            13,
            hex(C.ink2),
            230 * this._u,
            30 * this._u,
            true,
        );
        this._toastNode.active = false;

        this._modalRoot = this._uNode(this.node, 'ModalRoot', this._w, this._h);
    }

    private _buildHome(): void {
        const u = this._u;
        const W = this._w;
        const H = this._h;
        const insetTop = this._insetTop;
        const insetBottom = this._insetBottom;
        const cardW = Math.min(W * 0.94, 420 * u);
        const topW = cardW;
        const left = -topW / 2;
        const right = topW / 2;

        // top row: badge + coins
        const menuBtn = this._button(
            this._homeRoot,
            'HomeMenu',
            104 * u,
            36 * u,
            18 * u,
            '#ffffff',
            '☰ Menu',
            hex(C.purple),
            13,
            () => this._open('menu'),
            { shadow: true },
        );
        menuBtn.node.setPosition(left + 52 * u, H / 2 - insetTop - 38 * u, 0);

        const coins = this._button(
            this._homeRoot,
            'HomeCoins',
            92 * u,
            40 * u,
            20 * u,
            C.gold,
            '🍬 120',
            hex(C.goldInk),
            14,
            () => this._open('skins'),
        );
        coins.node.setPosition(right - 46 * u, H / 2 - insetTop - 40 * u, 0);
        this._homeCoins = coins.label;

        // hero
        const logo = this._label(
            this._homeRoot,
            'Jelly Cube 3D',
            30,
            hex(C.ink),
            cardW,
            46 * u,
            true,
            'center',
            true,
        );
        logo.node.setPosition(0, H / 2 - insetTop - 88 * u, 0);
        const tagline = this._label(
            this._homeRoot,
            'Squishy Physics · Endgame Puzzles · Global Ranks',
            13,
            hex(C.ink2),
            cardW,
            24 * u,
            true,
            'center',
            true,
        );
        tagline.node.setPosition(0, H / 2 - insetTop - 113 * u, 0);

        // actions card
        const cardH = 126 * u;
        const bannerPad = PlatformBridge.isNativeMobile ? 50 * u : 0;
        const cardY = -H / 2 + Math.max(26 * u, insetBottom + 8 * u) + bannerPad + cardH / 2;
        const card = this._surface(
            this._homeRoot,
            'HomeActions',
            cardW,
            cardH,
            26 * u,
            '#ffffff',
            undefined,
            true,
        );
        card.setPosition(0, cardY, 0);

        const innerW = cardW - 28 * u;
        const top = cardH / 2 - 14 * u;
        const cta = this._button(
            card,
            'HomePlay',
            innerW,
            48 * u,
            18 * u,
            C.purple,
            '▶ Play Level 1',
            hex(C.white),
            16,
            () => this.controller?.startLevel(this._state?.unlockedLevel ?? 1),
            { gradientTo: C.purple2, bold: true, shadow: true },
        );
        cta.node.setPosition(0, top - 24 * u, 0);
        this._homePlay = cta.label;

        const row2Y = top - 48 * u - 10 * u - 20 * u;
        const gap2 = 8 * u;
        const w2 = (innerW - gap2) / 2;
        const daily = this._button(
            card,
            'HomeDaily',
            w2,
            40 * u,
            14 * u,
            C.card,
            '📅 Daily (0d streak)',
            hex(C.dark),
            13,
            () => this.controller?.startDailyChallenge(),
        );
        daily.node.setPosition(-(w2 + gap2) / 2, row2Y, 0);
        this._homeDaily = daily.label;

        this._button(
            card,
            'HomeRanks',
            w2,
            40 * u,
            14 * u,
            C.card,
            '🏆 Global Ranks',
            hex(C.dark),
            13,
            () => this._open('leaderboard'),
        ).node.setPosition((w2 + gap2) / 2, row2Y, 0);

    }

    private _buildGameHud(): void {
        const u = this._u;
        const W = this._w;
        const H = this._h;
        const topY = H / 2 - this._insetTop - 36 * u;
        const barW = Math.min(W * 0.94, 440 * u);
        const barLeft = -barW / 2;
        const barRight = barW / 2;

        // Relative widths keep the four pills from colliding on narrow
        // screens; the middle pill absorbs whatever space is left.
        const margin = barW * 0.025;
        const barGap = barW * 0.014;
        const levelW = barW * 0.30;
        const coinsW = barW * 0.21;
        const pauseW = 40 * u;
        const levelX = barLeft + margin + levelW / 2;
        const pauseX = barRight - margin - pauseW / 2;
        const coinsX = pauseX - pauseW / 2 - barGap - coinsW / 2;
        const lvl = this._button(
            this._gameRoot,
            'LevelPill',
            levelW,
            40 * u,
            20 * u,
            '#ffffff',
            'Level 1  ▾',
            hex(C.ink),
            13,
            () => this._open('levels'),
            { shadow: true },
        );
        lvl.node.setPosition(levelX, topY, 0);
        this._titleLabel = lvl.label;

        const coins = this._button(
            this._gameRoot,
            'CoinsPill',
            coinsW,
            40 * u,
            20 * u,
            C.gold,
            '🍬 120',
            hex(C.goldInk),
            13,
            () => this._open('skins'),
            { shadow: true },
        );
        coins.node.setPosition(coinsX, topY, 0);
        this._coinsLabel = coins.label;

        this._button(
            this._gameRoot,
            'PauseBtn',
            pauseW,
            40 * u,
            20 * u,
            '#ffffff',
            '❚❚',
            hex(C.ink),
            12,
            () => {
                this.controller?.setPaused(true);
                this._open('pause');
            },
            { shadow: true },
        ).node.setPosition(pauseX, topY, 0);

        // Move count + timer on a second row, so the bar stays uncluttered.
        const movesW = Math.min(190 * u, barW * 0.52);
        const moves = this._surface(
            this._gameRoot,
            'MovesPill',
            movesW,
            30 * u,
            15 * u,
            '#ffffff',
            undefined,
            true,
        );
        moves.setPosition(0, topY - 44 * u, 0);
        this._subLabel = this._label(
            moves,
            '0/1 · 00:00.0',
            12,
            hex(C.ink2),
            movesW - 8 * u,
            30 * u,
            true,
            'center',
            true,
        );

        const dockW = Math.min(W * 0.94, 440 * u);
        const dockH = 54 * u;
        const dock = this._surface(
            this._gameRoot,
            'BottomDock',
            dockW,
            dockH,
            22 * u,
            '#ffffff',
            undefined,
            true,
        );
        dock.setPosition(
            0,
            -H / 2 + Math.max(20 * u, this._insetBottom + 8 * u) + dockH / 2,
            0,
        );

        const gap = 8 * u;
        const innerW = dockW - 16 * u;
        const w1 = (innerW - gap * 2) / 3.25;
        const w3 = w1 * 1.25;
        this._button(
            dock,
            'UndoBtn',
            w1,
            38 * u,
            16 * u,
            '#f3edf8',
            '↶ Undo',
            hex(C.dark),
            13,
            () => this.controller?.undoMove(),
        ).node.setPosition(-(innerW / 2) + w1 / 2, 0, 0);
        this._button(
            dock,
            'HintBtn',
            w1,
            38 * u,
            16 * u,
            C.pink,
            '💡 Hint',
            hex(C.white),
            13,
            () => this._open('hint'),
        ).node.setPosition(-(innerW / 2) + w1 + gap + w1 / 2, 0, 0);
        this._button(
            dock,
            'TutorialBtn',
            w3,
            38 * u,
            16 * u,
            C.orange,
            '🎬 Tutorial',
            hex(C.white),
            13,
            () => this._open('tutorial'),
        ).node.setPosition(innerW / 2 - w3 / 2, 0, 0);
    }

    // ------------------------------------------------------------------ state
    private _setSubLabel(s: GameUIState, time: string): void {
        if (s.playMode === 'level' && s.level) {
            this._subLabel.string = `${s.moves}/${s.level.parMoves} · ${time}`;
        } else {
            this._subLabel.string = `${s.moves} moves · ${time}`;
        }
    }

    private _refreshHUD(): void {
        const s = this._state;
        if (!s) return;

        this._homeRoot.active = s.onHome;
        this._gameRoot.active = !s.onHome;
        if (this._lastOnHome !== s.onHome) {
            const root = s.onHome ? this._homeRoot : this._gameRoot;
            this.scheduleOnce(() => this._redrawGraphics(root), 0);
        }
        this._lastOnHome = s.onHome;
        this._homeCoins.string = `🍬 ${s.coins}`;
        this._homePlay.string = `▶ Play Level ${s.unlockedLevel}`;
        this._homeDaily.string = `📅 Daily (${s.dailyStreak}d streak)`;

        if (s.playMode === 'level' && s.level) {
            this._titleLabel.string = `Level ${s.level.id}  ▾`;
        } else if (s.playMode === 'daily') {
            this._titleLabel.string = 'Daily  ▾';
        } else if (s.playMode === 'challenge') {
            this._titleLabel.string = `${s.challengeSize}×${s.challengeSize}  ▾`;
        } else {
            this._titleLabel.string = `Free ${s.freeSize}×${s.freeSize}  ▾`;
        }
        this._setSubLabel(s, formatDurationMs(s.elapsedMs));
        this._coinsLabel.string = `🍬 ${s.coins}`;

        this._syncBanner();

        if (s.toast && s.toast !== this._toastLabel.string) {
            this._toastLabel.string = s.toast;
            this._toastNode.active = true;
            const token = ++this._toastToken;
            this.scheduleOnce(() => {
                if (token === this._toastToken) this._toastNode.active = false;
            }, 2.6);
        }

        if (this._modal !== 'none') this._rebuildModal();
    }

    // ------------------------------------------------------------------ modal
    private _syncBanner(): void {
        // Banner only on the home screen and never under a modal.
        const onHome = this._state?.onHome ?? true;
        const visible = onHome && this._modal === 'none';
        if (visible !== this._bannerVisible) {
            this._bannerVisible = visible;
            trace(`banner:${visible ? 1 : 0}`);
            PlatformBridge.setBannerVisible(visible);
        }
    }

    private _open(kind: ModalKind): void {
        trace(`modal:${kind}`);
        this._modal = kind;
        this._rebuildModal();
    }

    private _close(): void {
        this._modal = 'none';
        this._rebuildModal();
    }

    private _rebuildModal(): void {
        this._modalRoot.removeAllChildren();
        this._mb = null;
        if (this.controller) this.controller.uiBlocking = this._modal !== 'none';
        this._syncBanner();
        if (this._modal === 'none' || !this._state) return;

        const u = this._u;
        const backdrop = this._uNode(this._modalRoot, 'Backdrop', this._w, this._h);
        const g = backdrop.addComponent(Graphics);
        g.fillColor = hex('#1c1028', 107);
        g.rect(-this._w / 2, -this._h / 2, this._w, this._h);
        g.fill();
        backdrop.addComponent(BlockInputEvents);
        backdrop.on(Node.EventType.TOUCH_END, () => {});

        const cardW = Math.min(this._w * 0.92, 400 * u);
        const card = this._uNode(backdrop, 'ModalCard', cardW, 0);
        this._mb = { card, w: cardW, cursor: 0, items: [] };

        switch (this._modal) {
            case 'pause':
                this._buildPause();
                break;
            case 'hint':
                this._buildHint();
                break;
            case 'tutorial':
                this._buildTutorial();
                break;
            case 'win':
                this._buildWin();
                break;
            case 'skins':
                this._buildSkins();
                break;
            case 'leaderboard':
                this._buildLeaderboard();
                break;
            case 'levels':
                this._buildLevels();
                break;
            case 'menu':
                this._buildMenu();
                break;
        }
        this._mbEnd();
    }

    private _mbAdd(node: Node, h: number, gap = 10): Node {
        const mb = this._mb!;
        node.parent = mb.card;
        node.setPosition(0, -(mb.cursor + h / 2), 0);
        mb.cursor += h + gap;
        mb.items.push(node);
        return node;
    }

    private _mbEnd(): void {
        const mb = this._mb;
        if (!mb) return;
        const u = this._u;
        const pad = 20 * u;
        const H = Math.max(120 * u, mb.cursor - 10 * u + pad * 2);
        mb.card.getComponent(UITransform)!.setContentSize(mb.w, H);
        const bg = this._surface(mb.card, 'CardBg', mb.w, H, 26 * u, '#fffcff', undefined, true);
        bg.setSiblingIndex(0);
        bg.setPosition(0, 0, 0);
        const shift = H / 2 - pad;
        for (const item of mb.items) {
            item.setPosition(item.position.x, item.position.y + shift, 0);
        }
        mb.card.setPosition(0, 0, 0);
        this._mb = null;
    }

    private _mbTitle(text: string, size = 20): void {
        const u = this._u;
        const node = this._uNode(this._mb!.card, 'Title', this._mb!.w - 40 * u, 28 * u);
        const lbl = node.addComponent(Label);
        lbl.useSystemFont = true;
        lbl.fontFamily = 'PingFang SC';
        lbl.string = text;
        lbl.fontSize = Math.round(size * u);
        lbl.lineHeight = Math.round(size * u * 1.3);
        lbl.color = hex('#382248');
        lbl.isBold = true;
        this._mbAdd(node, 28 * u, 10);
    }

    private _mbText(text: string, size = 14, color = '#664e76', h = 36): void {
        const u = this._u;
        const node = this._uNode(this._mb!.card, 'Text', this._mb!.w - 40 * u, h * u);
        const lbl = node.addComponent(Label);
        lbl.useSystemFont = true;
        lbl.fontFamily = 'PingFang SC';
        lbl.string = text;
        lbl.fontSize = Math.round(size * u);
        lbl.lineHeight = Math.round(size * u * 1.45);
        lbl.color = hex(color);
        lbl.enableWrapText = true;
        lbl.overflow = Label.Overflow.CLAMP;
        lbl.horizontalAlign = Label.HorizontalAlign.CENTER;
        lbl.verticalAlign = Label.VerticalAlign.CENTER;
        this._mbAdd(node, h * u, 8);
    }

    private _mbButton(
        text: string,
        kind: 'primary' | 'gold' | 'secondary',
        onClick: () => void,
        h = 44,
    ): void {
        const u = this._u;
        const fill =
            kind === 'primary' ? C.purple : kind === 'gold' ? C.orange : '#ece4f2';
        const color = kind === 'secondary' ? hex(C.dark) : hex(C.white);
        const gradient = kind === 'primary' ? C.purple2 : undefined;
        const btn = this._button(
            this._mb!.card,
            'ModalBtn',
            this._mb!.w - 40 * u,
            h * u,
            16 * u,
            fill,
            text,
            color,
            15,
            onClick,
            { gradientTo: gradient, bold: true },
        );
        this._mbAdd(btn.node, h * u, 10);
    }

    private _mbHeader(title: string, right?: Node): void {
        const mb = this._mb!;
        const u = this._u;
        const rowH = 32 * u;
        const row = this._uNode(mb.card, 'Header', mb.w - 40 * u, rowH);
        const lbl = this._label(
            row,
            title,
            20,
            hex('#382248'),
            mb.w - 40 * u - 60 * u,
            rowH,
            true,
            'left',
        );
        lbl.node.setPosition(-(mb.w - 40 * u) / 2 + (mb.w - 40 * u - 60 * u) / 2, 0, 0);
        if (right) {
            right.parent = row;
            right.setPosition((mb.w - 40 * u) / 2 - right.getComponent(UITransform)!.width / 2, 0, 0);
        }
        this._mbAdd(row, rowH, 10);
    }

    private _closeButton(): Node {
        const u = this._u;
        const btn = this._button(
            this._mb!.card,
            'CloseX',
            32 * u,
            32 * u,
            16 * u,
            '#f0e8f8',
            '✕',
            hex('#4a305c'),
            15,
            () => this._close(),
        );
        return btn.node;
    }

    private _buildMenu(): void {
        this._mbTitle('Menu');
        this._mbButton('🍮 Skins', 'primary', () => this._open('skins'));
        this._mbButton('📤 Share +15 🍬', 'secondary', () => {
            this._close();
            this.controller?.shareForSugar();
        });
        this._mbButton('⭐ Rate', 'secondary', () => {
            this._close();
            this.controller?.rateApp();
        });
        this._mbButton('🎬 +30 🍬', 'gold', () => {
            this._close();
            this.controller?.claimFreeSugarAd();
        });
        this._mbButton('Privacy & Terms', 'secondary', () => sys.openURL(PRIVACY_URL));
        this._mbButton('Close', 'secondary', () => this._close());
    }

    /** QA hook used by JellyBootstrap launch arguments. */
    debugOpen(kind: string): void {
        if (!this._state) {
            this.scheduleOnce(() => this.debugOpen(kind), 0.2);
            return;
        }
        if (
            kind === 'menu' ||
            kind === 'skins' ||
            kind === 'levels' ||
            kind === 'leaderboard' ||
            kind === 'pause' ||
            kind === 'hint' ||
            kind === 'tutorial'
        ) {
            this._open(kind);
        }
    }

    private _buildPause(): void {
        const s = this._state!;
        this._mbTitle('Paused');
        this._mbButton('🏠 Home', 'primary', () => {
            this._close();
            this.controller?.showHome();
        });
        this._mbButton('↻ Restart Level', 'secondary', () => {
            this._close();
            this.controller?.resetCurrent();
        });
        this._mbButton(s.muted ? '🔇 Sound: Off' : '🔊 Sound: On', 'secondary', () => {
            this.controller?.toggleMute();
        });
        this._mbButton('▶ Resume', 'secondary', () => {
            this._close();
            this.controller?.setPaused(false);
        });
    }

    private _buildHint(): void {
        const s = this._state!;
        this._mbTitle('💡 Need a Hint?');
        this._mbText('Highlights the next slice & rotation direction without hurting your score.', 14, '#664e76', 48);
        if (s.coins >= 20) {
            this._mbButton('Use 20 🍬 (Instant)', 'primary', () => {
                this._close();
                this.controller?.triggerHint(true);
            });
        }
        this._mbButton('Watch Ad (Free Hint)', 'gold', () => {
            this._close();
            this.controller?.triggerHint(false);
        });
        this._mbButton('Cancel', 'secondary', () => this._close());
    }

    private _buildTutorial(): void {
        const s = this._state!;
        this._mbTitle('🎬 Solve Tutorial');
        this._mbText(
            'Step-by-step solve tutorial.\nTutorial runs do not count toward stars or global rankings.',
            14,
            '#664e76',
            48,
        );
        if (s.coins >= 60) {
            this._mbButton('Use 60 🍬 (Instant)', 'primary', () => {
                this._close();
                this.controller?.triggerTutorial(true);
            });
        }
        this._mbButton('Watch Ad (Free Tutorial)', 'gold', () => {
            this._close();
            this.controller?.triggerTutorial(false);
        });
        this._mbButton('Cancel', 'secondary', () => this._close());
    }

    private _buildWin(): void {
        const s = this._state!;
        const u = this._u;
        if (s.assistedSolve) {
            this._mbTitle('Tutorial Complete');
            this._mbText(
                'Step-by-step solve tutorial finished!\nTutorial runs do not count toward stars or global rankings.',
                14,
                '#664e76',
                52,
            );
            this._mbButton('Try It Yourself', 'primary', () => {
                this._close();
                this.controller?.resetCurrent();
            });
            this._mbButton('Back to Home', 'secondary', () => {
                this._close();
                this.controller?.showHome();
            });
            return;
        }

        const stars = s.playMode === 'level' && s.level ? computeStars(s.moves, s.level) : 3;
        this._mbTitle('Jelly Solved!');
        const starsNode = this._uNode(this._mb!.card, 'Stars', this._mb!.w - 40 * u, 48 * u);
        const starsLbl = this._label(
            starsNode,
            '★'.repeat(stars) + '☆'.repeat(3 - stars),
            36,
            hex('#ffb218'),
            this._mb!.w - 40 * u,
            48 * u,
            true,
        );
        starsLbl.node.setPosition(0, 0, 0);
        this._mbAdd(starsNode, 48 * u, 6);

        if (s.playMode === 'challenge') {
            const lb = getGlobalLeaderboard(
                s.challengeSize,
                s.playerName,
                s.bestRecords[s.challengeSize],
            );
            this._mbText(
                `🏆 ${s.challengeSize}×${s.challengeSize} Global Rank #${lb.playerRank}`,
                14,
                C.purple,
                24,
            );
        } else if (s.playMode === 'daily' && s.lastDailyRewardLabel) {
            this._mbText(`🔥 ${s.lastDailyRewardLabel}`, 14, C.purple, 24);
        }

        const reward =
            s.playMode === 'challenge'
                ? s.challengeSize * 8
                : s.playMode === 'free'
                  ? 20
                  : (s.level?.rewardCoins ?? 20);
        this._mbText(
            `Time: ${formatDurationMs(s.elapsedMs)} · ${s.moves} moves · +${reward} 🍬`,
            14,
            '#664e76',
            24,
        );

        if (s.lastPlayerMoveCount > 0) {
            this._mbButton(`🎬 Watch Replay (${s.lastPlayerMoveCount} moves)`, 'secondary', () => {
                this._close();
                this.controller?.replayLastSolve(() => {
                    this._modal = 'win';
                    this._rebuildModal();
                });
            });
        }
        if (!this._doubleClaimed) {
            this._mbButton(`Watch Ad for 2× Sugar (+${reward})`, 'gold', async () => {
                this._doubleClaimed = true;
                await this.controller?.claimDoubleRewardWithAd();
                this._rebuildModal();
            });
        }
        if (s.playMode === 'challenge') {
            this._mbButton('Global Leaderboard', 'secondary', () => this._open('leaderboard'));
        }
        this._mbButton(
            s.playMode === 'level' && s.level && s.level.id < TOTAL_LEVELS ? 'Next Level' : 'Play Again',
            'primary',
            () => {
                this._close();
                if (s.playMode === 'level' && s.level && s.level.id < TOTAL_LEVELS) {
                    this.controller?.startLevel(s.level.id + 1);
                } else {
                    this.controller?.resetCurrent();
                }
            },
        );
    }

    private _buildSkins(): void {
        const s = this._state!;
        const u = this._u;
        const mb = this._mb!;
        this._mbHeader('Jelly Boutique', this._closeButton());

        // category tabs
        const cats: Array<{ id: 'all' | JellySkinCategory; label: string }> = [
            { id: 'all', label: `All (${JELLY_SKINS.length})` },
            { id: 'jelly', label: 'Jelly' },
            { id: 'art', label: 'AI Art' },
            { id: 'fx', label: 'FX' },
        ];
        const tabsW = mb.w - 40 * u;
        const tabW = (tabsW - 3 * 6 * u) / 4;
        const tabs = this._uNode(mb.card, 'Tabs', tabsW, 30 * u);
        cats.forEach((c, i) => {
            const active = this._skinCat === c.id;
            const b = this._button(
                tabs,
                `Cat_${c.id}`,
                tabW,
                30 * u,
                12 * u,
                active ? C.purple : '#f0e8f8',
                c.label,
                active ? hex(C.white) : hex(C.dark),
                13,
                () => {
                    this._skinCat = c.id;
                    this._rebuildModal();
                },
            );
            b.node.setPosition(-tabsW / 2 + tabW / 2 + i * (tabW + 6 * u), 0, 0);
        });
        this._mbAdd(tabs, 30 * u, 10);

        const list =
            this._skinCat === 'all'
                ? JELLY_SKINS
                : JELLY_SKINS.filter((sk) => sk.category === this._skinCat);
        const cols = 2;
        const gap = 10 * u;
        const cellW = (tabsW - gap) / 2;
        const cellH = 86 * u;
        for (let i = 0; i < list.length; i += cols) {
            const row = this._uNode(mb.card, 'SkinRow', tabsW, cellH);
            for (let c = 0; c < cols; c++) {
                const skin = list[i + c];
                if (!skin) break;
                const active = s.activeSkinId === skin.id;
                const unlocked = s.unlockedSkins.includes(skin.id);
                const card = this._surface(
                    row,
                    `Skin_${skin.id}`,
                    cellW,
                    cellH,
                    18 * u,
                    active ? '#f6f1ff' : '#f8f3fc',
                );
                card.setPosition(-tabsW / 2 + cellW / 2 + c * (cellW + gap), 0, 0);

                // palette bar
                const pal = this._uNode(card, 'Palette', 34 * u, 34 * u);
                pal.setPosition(-cellW / 2 + 22 * u, cellH / 2 - 24 * u, 0);
                const pg = pal.addComponent(Graphics);
                for (let k = 0; k < 3; k++) {
                    for (let j = 0; j < 2; j++) {
                        pg.fillColor = hex(skin.colors[(k + j * 3) % skin.colors.length]);
                        pg.roundRect(
                            -17 * u + k * 11 * u,
                            17 * u - 11 * u - j * 11 * u,
                            10 * u,
                            10 * u,
                            2 * u,
                        );
                        pg.fill();
                    }
                }

                const tag = this._uNode(card, 'Tag', 42 * u, 16 * u);
                tag.setPosition(cellW / 2 - 26 * u, cellH / 2 - 18 * u, 0);
                const tagBg = this._surface(tag, 'TagBg', 42 * u, 16 * u, 8 * u, active ? C.purple : '#efe6fa');
                tagBg.setPosition(0, 0, 0);
                this._label(tagBg, skin.tag, 9, active ? hex(C.white) : hex('#673ab7'), 40 * u, 16 * u, true);

                const name = this._label(
                    card,
                    skin.name,
                    12,
                    hex(C.ink),
                    cellW - 16 * u,
                    16 * u,
                    true,
                    'left',
                );
                name.node.setPosition(0, 2 * u, 0);

                const cta = this._surface(
                    card,
                    'Cta',
                    cellW - 20 * u,
                    17 * u,
                    8 * u,
                    active ? C.purple : unlocked ? '#ede4f7' : C.gold,
                );
                cta.setPosition(0, -cellH / 2 + 14 * u, 0);
                this._label(
                    cta,
                    active ? '✓ Equipped' : unlocked ? 'Use Skin' : `🍬 ${skin.cost}`,
                    10,
                    active ? hex(C.white) : unlocked ? hex('#4a305c') : hex(C.goldInk),
                    cellW - 24 * u,
                    17 * u,
                    true,
                );

                card.addComponent(Button);
                card.on(Button.EventType.CLICK, () => {
                    this.controller?.selectOrUnlockSkin(skin.id);
                    this._rebuildModal();
                });
            }
            this._mbAdd(row, cellH, gap);
        }
        this._mbText(`Balance: 🍬 ${s.coins} · tap the ad chip for +30`, 11, '#846d91', 18);
    }

    private _buildLeaderboard(): void {
        const s = this._state!;
        const u = this._u;
        const mb = this._mb!;
        this._mbHeader('Global Leaderboard', this._closeButton());

        const tabsW = mb.w - 40 * u;
        const tabW = (tabsW - 4 * 5 * u) / 5;
        const tabs = this._uNode(mb.card, 'LbTabs', tabsW, 30 * u);
        CHALLENGE_SIZES.forEach((sz, i) => {
            const active = this._lbSize === sz;
            const b = this._button(
                tabs,
                `Tab_${sz}`,
                tabW,
                30 * u,
                12 * u,
                active ? C.purple : '#f0e8f8',
                `${sz}×${sz}`,
                active ? hex(C.white) : hex(C.dark),
                13,
                () => {
                    this._lbSize = sz;
                    this._rebuildModal();
                },
            );
            b.node.setPosition(-tabsW / 2 + tabW / 2 + i * (tabW + 5 * u), 0, 0);
        });
        this._mbAdd(tabs, 30 * u, 10);

        const localLb = getGlobalLeaderboard(this._lbSize, s.playerName, s.bestRecords[this._lbSize]);
        const rowCount = Math.max(1, Math.min(6, localLb.entries.length));
        const rowH = 26 * u;
        const rowsH = rowCount * (rowH + 4 * u);
        const rowsNode = this._uNode(mb.card, 'Rows', tabsW, rowsH);
        const renderRows = (entries: typeof localLb.entries) => {
            rowsNode.removeAllChildren();
            entries.slice(0, 6).forEach((e, idx) => {
                const row = this._surface(
                    rowsNode,
                    `Row_${idx}`,
                    tabsW,
                    rowH,
                    12 * u,
                    e.isPlayer ? '#ede3ff' : '#f7f3fb',
                );
                row.setPosition(0, rowsH / 2 - rowH / 2 - idx * (rowH + 4 * u), 0);
                this._label(row, `#${e.rank}`, 12, hex(C.purple), 40 * u, rowH, true, 'left').node.setPosition(
                    -tabsW / 2 + 22 * u,
                    0,
                    0,
                );
                this._label(
                    row,
                    `${e.name} (${e.region})`,
                    12,
                    hex(C.ink),
                    tabsW - 190 * u,
                    rowH,
                    false,
                    'left',
                ).node.setPosition(-tabsW / 2 + 60 * u + (tabsW - 190 * u) / 2, 0, 0);
                this._label(
                    row,
                    `${formatDurationMs(e.timeMs)} · ${e.moves}m`,
                    12,
                    hex(C.ink),
                    120 * u,
                    rowH,
                    true,
                    'left',
                ).node.setPosition(tabsW / 2 - 60 * u, 0, 0);
            });
        };
        renderRows(localLb.entries);
        this._mbAdd(rowsNode, rowsH, 10);

        fetchGlobalLeaderboard(
            this._lbSize,
            s.playerId,
            s.playerName,
            s.bestRecords[this._lbSize],
        ).then((live) => {
            if (this._modal === 'leaderboard' && rowsNode.isValid) renderRows(live.entries);
        });

        const rec = getRecommendedChallenge(s.unlockedLevel);
        this._mbButton(`Start ${this._lbSize}×${this._lbSize} Race`, 'primary', () => {
            this._close();
            this.controller?.startChallenge(this._lbSize);
        });
        this._mbText(`Recommended: ${rec.size}×${rec.size}`, 11, '#846d91', 16);
    }

    private _buildLevels(): void {
        const s = this._state!;
        const u = this._u;
        const mb = this._mb!;
        this._mbTitle(`Select Level (1–${TOTAL_LEVELS})`);

        const cols = 5;
        const gap = 8 * u;
        const gridW = mb.w - 40 * u;
        const cellW = (gridW - gap * 4) / cols;
        const cellH = 44 * u;
        const rows = Math.ceil(TOTAL_LEVELS / cols);
        for (let r = 0; r < rows; r++) {
            const rowNode = this._uNode(mb.card, 'LvlRow', gridW, cellH);
            for (let c = 0; c < cols; c++) {
                const id = r * cols + c + 1;
                if (id > TOTAL_LEVELS) break;
                const unlocked = id <= s.unlockedLevel;
                const stars = s.levelStars[id] ?? 0;
                const cell = this._button(
                    rowNode,
                    `Lvl_${id}`,
                    cellW,
                    cellH,
                    12 * u,
                    unlocked ? '#f0e8f8' : '#ececef',
                    `${id}  ${unlocked ? '★'.repeat(stars) || '·' : '🔒'}`,
                    unlocked ? hex(C.dark) : hex('#9a9aa6'),
                    11,
                    () => {
                        if (!unlocked) return;
                        this._close();
                        this.controller?.startLevel(id);
                    },
                );
                cell.node.setPosition(-gridW / 2 + cellW / 2 + c * (cellW + gap), 0, 0);
            }
            this._mbAdd(rowNode, cellH, gap);
        }
        this._mbButton('Close', 'secondary', () => this._close());
    }
}
