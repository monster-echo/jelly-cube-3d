// Jelly Cube 3D — Minimalist English Cocos Canvas HUD, Home Screen, & Modals

import {
    _decorator,
    Button,
    Color,
    Component,
    Graphics,
    Label,
    Node,
    UITransform,
    Widget,
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

const { ccclass, property } = _decorator;

type ModalKind =
    | 'none'
    | 'pause'
    | 'win'
    | 'skins'
    | 'levels'
    | 'leaderboard'
    | 'hint'
    | 'tutorial';

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

    private _homeCoinsLabel!: Label;
    private _homePlayLabel!: Label;
    private _homeDailyLabel!: Label;

    private _titleLabel!: Label;
    private _subLabel!: Label;
    private _coinsLabel!: Label;
    private _toastLabel!: Label;

    onLoad(): void {
        this._buildLayout();
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
            this._formatSubLabel(this._state, tStr);
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

    // --------------------------------------------------------- UI Primitives
    private _makePanel(
        name: string,
        parent: Node,
        w: number,
        h: number,
        fill: Color,
        radius = 18,
    ): { node: Node; gfx: Graphics } {
        const node = new Node(name);
        node.parent = parent;
        node.addComponent(UITransform).setContentSize(w, h);
        const gfx = node.addComponent(Graphics);
        gfx.fillColor = fill;
        gfx.roundRect(-w / 2, -h / 2, w, h, radius);
        gfx.fill();
        return { node, gfx };
    }

    private _makeLabel(
        name: string,
        parent: Node,
        text: string,
        fontSize: number,
        color: Color,
        w = 240,
        h = 40,
    ): Label {
        const node = new Node(name);
        node.parent = parent;
        node.addComponent(UITransform).setContentSize(w, h);
        const lbl = node.addComponent(Label);
        lbl.string = text;
        lbl.fontSize = fontSize;
        lbl.lineHeight = fontSize + 6;
        lbl.color = color;
        lbl.horizontalAlign = Label.HorizontalAlign.CENTER;
        lbl.verticalAlign = Label.VerticalAlign.CENTER;
        return lbl;
    }

    private _makeButton(
        name: string,
        parent: Node,
        w: number,
        h: number,
        text: string,
        bg: Color,
        textColor: Color,
        onClick: () => void,
        fontSize = 20,
    ): { node: Node; label: Label } {
        const { node } = this._makePanel(name, parent, w, h, bg, Math.min(26, h / 2));
        const label = this._makeLabel('Label', node, text, fontSize, textColor, w - 16, h);
        const btn = node.addComponent(Button);
        btn.transition = Button.Transition.SCALE;
        btn.zoomScale = 0.94;
        node.on(Button.EventType.CLICK, onClick, this);
        return { node, label };
    }

    private _pinWidget(node: Node, top?: number, bottom?: number): void {
        const w = node.addComponent(Widget);
        if (top !== undefined) {
            w.isAlignTop = true;
            w.top = top;
        }
        if (bottom !== undefined) {
            w.isAlignBottom = true;
            w.bottom = bottom;
        }
    }

    // --------------------------------------------------------- Layout
    private _buildLayout(): void {
        this._homeRoot = new Node('HomeRoot');
        this._homeRoot.parent = this.node;
        this._homeRoot.addComponent(UITransform).setContentSize(720, 1280);

        this._gameRoot = new Node('GameRoot');
        this._gameRoot.parent = this.node;
        this._gameRoot.addComponent(UITransform).setContentSize(720, 1280);

        this._buildHomeScreen();
        this._buildInGameHUD();

        this._toastLabel = this._makeLabel(
            'Toast',
            this.node,
            '',
            20,
            new Color(74, 48, 92, 255),
            560,
            40,
        );
        this._pinWidget(this._toastLabel.node, 118);

        this._modalRoot = new Node('ModalRoot');
        this._modalRoot.parent = this.node;
    }

    private _buildHomeScreen(): void {
        const badge = this._makePanel(
            'HomeBadge',
            this._homeRoot,
            210,
            44,
            new Color(255, 255, 255, 225),
            22,
        ).node;
        badge.setPosition(-215, 575, 0);
        this._makeLabel('Lbl', badge, 'JELLY CUBE 3D', 18, new Color(116, 72, 245, 255), 200, 40);

        const coinsPill = this._makeButton(
            'HomeCoins',
            this._homeRoot,
            135,
            48,
            '120',
            new Color(255, 232, 168, 255),
            new Color(130, 74, 10, 255),
            () => {
                this._modal = 'skins';
                this._rebuildModal();
            },
            20,
        );
        coinsPill.node.setPosition(250, 575, 0);
        this._homeCoinsLabel = coinsPill.label;

        const logo = this._makeLabel(
            'HomeLogo',
            this._homeRoot,
            'Jelly Cube 3D',
            48,
            new Color(52, 34, 62, 255),
            560,
            64,
        );
        logo.node.setPosition(0, 470, 0);

        const card = this._makePanel(
            'HomeActions',
            this._homeRoot,
            650,
            320,
            new Color(255, 255, 255, 232),
            30,
        ).node;
        this._pinWidget(card, undefined, 36);

        const playBtn = this._makeButton(
            'HomePlay',
            card,
            600,
            82,
            'Play Level 1',
            new Color(116, 72, 245, 255),
            new Color(255, 255, 255, 255),
            () => this.controller?.startLevel(this._state?.unlockedLevel ?? 1),
            26,
        );
        playBtn.node.setPosition(0, 96, 0);
        this._homePlayLabel = playBtn.label;

        const dailyBtn = this._makeButton(
            'HomeDaily',
            card,
            292,
            68,
            'Daily (0d streak)',
            new Color(242, 234, 248, 255),
            new Color(62, 42, 78, 255),
            () => this.controller?.startDailyChallenge(),
            20,
        );
        dailyBtn.node.setPosition(-154, 4, 0);
        this._homeDailyLabel = dailyBtn.label;

        this._makeButton(
            'HomeRanks',
            card,
            292,
            68,
            'Global Ranks',
            new Color(242, 234, 248, 255),
            new Color(62, 42, 78, 255),
            () => {
                this._modal = 'leaderboard';
                this._rebuildModal();
            },
            20,
        ).node.setPosition(154, 4, 0);

        this._makeButton(
            'HomeSkins',
            card,
            142,
            60,
            'Skins',
            new Color(247, 243, 251, 255),
            new Color(74, 48, 92, 255),
            () => {
                this._modal = 'skins';
                this._rebuildModal();
            },
            18,
        ).node.setPosition(-228, -76, 0);

        this._makeButton(
            'HomeShare',
            card,
            142,
            60,
            'Share +15',
            new Color(247, 243, 251, 255),
            new Color(74, 48, 92, 255),
            () => this.controller?.shareForSugar(),
            18,
        ).node.setPosition(-76, -76, 0);

        this._makeButton(
            'HomeRate',
            card,
            142,
            60,
            'Rate',
            new Color(247, 243, 251, 255),
            new Color(74, 48, 92, 255),
            () => this.controller?.rateApp(),
            18,
        ).node.setPosition(76, -76, 0);

        this._makeButton(
            'HomeAd',
            card,
            142,
            60,
            '+30 Sugar',
            new Color(255, 232, 168, 255),
            new Color(130, 74, 10, 255),
            () => this.controller?.claimFreeSugarAd(),
            18,
        ).node.setPosition(228, -76, 0);
    }

    private _buildInGameHUD(): void {
        const lvlBtn = this._makeButton(
            'LevelPill',
            this._gameRoot,
            165,
            56,
            'Level 1',
            new Color(255, 255, 255, 230),
            new Color(52, 34, 62, 255),
            () => {
                this._modal = this._modal === 'levels' ? 'none' : 'levels';
                this._rebuildModal();
            },
            20,
        );
        lvlBtn.node.setPosition(-245, 575, 0);
        this._titleLabel = lvlBtn.label;

        const movesPill = this._makePanel(
            'MovesPill',
            this._gameRoot,
            230,
            56,
            new Color(255, 255, 255, 230),
            28,
        ).node;
        movesPill.setPosition(-15, 575, 0);
        this._subLabel = this._makeLabel(
            'Sub',
            movesPill,
            '0/1 · 00:00.0',
            19,
            new Color(108, 77, 128, 255),
            220,
            44,
        );

        const coinsBtn = this._makeButton(
            'CoinsPill',
            this._gameRoot,
            135,
            56,
            '120',
            new Color(255, 232, 168, 255),
            new Color(130, 74, 10, 255),
            () => {
                this._modal = 'skins';
                this._rebuildModal();
            },
            20,
        );
        coinsBtn.node.setPosition(185, 575, 0);
        this._coinsLabel = coinsBtn.label;

        this._makeButton(
            'PauseBtn',
            this._gameRoot,
            58,
            56,
            '||',
            new Color(255, 255, 255, 230),
            new Color(52, 34, 62, 255),
            () => {
                this.controller?.setPaused(true);
                this._modal = 'pause';
                this._rebuildModal();
            },
            22,
        ).node.setPosition(295, 575, 0);

        const dock = this._makePanel(
            'BottomDock',
            this._gameRoot,
            660,
            88,
            new Color(255, 255, 255, 230),
            28,
        ).node;
        this._pinWidget(dock, undefined, 32);

        this._makeButton(
            'UndoBtn',
            dock,
            195,
            64,
            'Undo',
            new Color(243, 237, 248, 255),
            new Color(62, 42, 78, 255),
            () => this.controller?.undoMove(),
            21,
        ).node.setPosition(-215, 0, 0);

        this._makeButton(
            'HintBtn',
            dock,
            195,
            64,
            'Hint',
            new Color(255, 114, 152, 255),
            new Color(255, 255, 255, 255),
            () => {
                this._modal = 'hint';
                this._rebuildModal();
            },
            21,
        ).node.setPosition(-8, 0, 0);

        this._makeButton(
            'TutorialBtn',
            dock,
            215,
            64,
            'Tutorial',
            new Color(255, 168, 48, 255),
            new Color(255, 255, 255, 255),
            () => {
                this._modal = 'tutorial';
                this._rebuildModal();
            },
            21,
        ).node.setPosition(208, 0, 0);
    }

    private _formatSubLabel(s: GameUIState, tStr: string): void {
        if (s.playMode === 'level' && s.level) {
            this._subLabel.string = `${s.moves}/${s.level.parMoves} · ${tStr}`;
        } else {
            this._subLabel.string = `${s.moves} moves · ${tStr}`;
        }
    }

    private _refreshHUD(): void {
        const s = this._state;
        if (!s) return;

        this._homeRoot.active = s.onHome;
        this._gameRoot.active = !s.onHome;

        this._homeCoinsLabel.string = String(s.coins);
        this._homePlayLabel.string = `Play Level ${s.unlockedLevel}`;
        this._homeDailyLabel.string = `Daily (${s.dailyStreak}d streak)`;

        if (s.playMode === 'level' && s.level) {
            this._titleLabel.string = `Level ${s.level.id}`;
        } else if (s.playMode === 'daily') {
            this._titleLabel.string = 'Daily';
        } else if (s.playMode === 'challenge') {
            this._titleLabel.string = `${s.challengeSize}×${s.challengeSize} Race`;
        } else {
            this._titleLabel.string = `Free ${s.freeSize}×${s.freeSize}`;
        }

        this._formatSubLabel(s, formatDurationMs(s.elapsedMs));
        this._coinsLabel.string = String(s.coins);
        this._toastLabel.string = s.toast;

        if (this._modal !== 'none') {
            this._rebuildModal();
        }
    }

    private _rebuildModal(): void {
        this._modalRoot.removeAllChildren();
        if (this._modal === 'none' || !this._state) return;

        const s = this._state;
        const card = this._makePanel(
            'ModalCard',
            this._modalRoot,
            620,
            700,
            new Color(255, 252, 255, 250),
            32,
        ).node;

        if (this._modal === 'pause') {
            this._makeLabel('Title', card, 'Paused', 32, new Color(56, 34, 72, 255), 400, 46).node.setPosition(0, 210, 0);
            this._makeButton('Home', card, 460, 74, 'Home', new Color(116, 72, 245, 255), new Color(255, 255, 255, 255), () => {
                this._modal = 'none';
                this._rebuildModal();
                this.controller?.showHome();
            }, 24).node.setPosition(0, 90, 0);
            this._makeButton('Restart', card, 460, 68, 'Restart Level', new Color(238, 228, 246, 255), new Color(62, 42, 78, 255), () => {
                this._modal = 'none';
                this._rebuildModal();
                this.controller?.resetCurrent();
            }, 22).node.setPosition(0, 0, 0);
            this._makeButton('Sound', card, 460, 68, s.muted ? 'Sound: Off' : 'Sound: On', new Color(238, 228, 246, 255), new Color(62, 42, 78, 255), () => {
                this.controller?.toggleMute();
            }, 22).node.setPosition(0, -86, 0);
            this._makeButton('Resume', card, 460, 74, 'Resume', new Color(238, 228, 246, 255), new Color(62, 42, 78, 255), () => {
                this._modal = 'none';
                this._rebuildModal();
                this.controller?.setPaused(false);
            }, 24).node.setPosition(0, -180, 0);
            return;
        }

        if (this._modal === 'hint') {
            this._makeLabel('Title', card, 'Need a Hint?', 30, new Color(56, 34, 72, 255), 440, 44).node.setPosition(0, 170, 0);
            this._makeLabel('Desc', card, 'Shows the next slice direction\nwithout hurting your score.', 22, new Color(102, 78, 118, 255), 480, 76).node.setPosition(0, 80, 0);
            if (s.coins >= 20) {
                this._makeButton('UseCoins', card, 440, 70, 'Use 20 Sugar (Instant)', new Color(116, 72, 245, 255), new Color(255, 255, 255, 255), () => {
                    this._modal = 'none';
                    this._rebuildModal();
                    this.controller?.triggerHint(true);
                }, 22).node.setPosition(0, -25, 0);
            }
            this._makeButton('WatchAd', card, 440, 70, 'Watch Ad (Free Hint)', new Color(255, 168, 48, 255), new Color(255, 255, 255, 255), () => {
                this._modal = 'none';
                this._rebuildModal();
                this.controller?.triggerHint(false);
            }, 22).node.setPosition(0, -110, 0);
            this._makeButton('Cancel', card, 440, 62, 'Cancel', new Color(236, 228, 242, 255), new Color(62, 42, 78, 255), () => {
                this._modal = 'none';
                this._rebuildModal();
            }, 20).node.setPosition(0, -195, 0);
            return;
        }

        if (this._modal === 'tutorial') {
            this._makeLabel('Title', card, 'Solve Tutorial', 30, new Color(56, 34, 72, 255), 440, 44).node.setPosition(0, 175, 0);
            this._makeLabel('Desc', card, 'Step-by-step solve tutorial.\nTutorial runs are unranked.', 22, new Color(102, 78, 118, 255), 480, 76).node.setPosition(0, 85, 0);
            if (s.coins >= 60) {
                this._makeButton('UseCoins', card, 440, 70, 'Use 60 Sugar (Instant)', new Color(116, 72, 245, 255), new Color(255, 255, 255, 255), () => {
                    this._modal = 'none';
                    this._rebuildModal();
                    this.controller?.triggerTutorial(true);
                }, 22).node.setPosition(0, -25, 0);
            }
            this._makeButton('WatchAd', card, 440, 70, 'Watch Ad (Free Tutorial)', new Color(255, 168, 48, 255), new Color(255, 255, 255, 255), () => {
                this._modal = 'none';
                this._rebuildModal();
                this.controller?.triggerTutorial(false);
            }, 22).node.setPosition(0, -110, 0);
            this._makeButton('Cancel', card, 440, 62, 'Cancel', new Color(236, 228, 242, 255), new Color(62, 42, 78, 255), () => {
                this._modal = 'none';
                this._rebuildModal();
            }, 20).node.setPosition(0, -195, 0);
            return;
        }

        if (this._modal === 'win') {
            if (s.assistedSolve) {
                this._makeLabel('Title', card, 'Tutorial Complete', 32, new Color(56, 34, 72, 255), 480, 46).node.setPosition(0, 160, 0);
                this._makeLabel('Info', card, 'Tutorial runs do not count\ntoward stars or global ranks.', 22, new Color(102, 78, 118, 255), 480, 80).node.setPosition(0, 50, 0);
                this._makeButton('Retry', card, 440, 72, 'Try It Yourself', new Color(116, 72, 245, 255), new Color(255, 255, 255, 255), () => {
                    this._modal = 'none';
                    this._rebuildModal();
                    this.controller?.resetCurrent();
                }, 23).node.setPosition(0, -70, 0);
                this._makeButton('Home', card, 440, 66, 'Back to Home', new Color(236, 228, 242, 255), new Color(62, 42, 78, 255), () => {
                    this._modal = 'none';
                    this._rebuildModal();
                    this.controller?.showHome();
                }, 22).node.setPosition(0, -160, 0);
                return;
            }

            const stars = s.playMode === 'level' && s.level ? computeStars(s.moves, s.level) : 3;
            const starStr = '★'.repeat(stars) + '☆'.repeat(3 - stars);
            const reward =
                s.playMode === 'challenge'
                    ? s.challengeSize * 8
                    : s.playMode === 'free'
                      ? 20
                      : s.level?.rewardCoins ?? 20;

            this._makeLabel('WinTitle', card, 'Jelly Solved!', 34, new Color(56, 34, 72, 255), 480, 46).node.setPosition(0, 250, 0);
            this._makeLabel('Stars', card, starStr, 48, new Color(255, 178, 24, 255), 360, 60).node.setPosition(0, 175, 0);
            this._makeLabel(
                'WinInfo',
                card,
                `Time: ${formatDurationMs(s.elapsedMs)} · ${s.moves} moves · +${reward} Sugar`,
                22,
                new Color(102, 78, 118, 255),
                520,
                44,
            ).node.setPosition(0, 100, 0);

            if (s.lastPlayerMoveCount > 0) {
                this._makeButton('Replay', card, 440, 64, `Watch Replay (${s.lastPlayerMoveCount}m)`, new Color(236, 228, 242, 255), new Color(62, 42, 78, 255), () => {
                    this._modal = 'none';
                    this._rebuildModal();
                    this.controller?.replayLastSolve(() => {
                        this._modal = 'win';
                        this._rebuildModal();
                    });
                }, 21).node.setPosition(0, 10, 0);
            }

            if (!this._doubleClaimed) {
                this._makeButton('DoubleBtn', card, 440, 68, `Watch Ad for 2× Sugar (+${reward})`, new Color(255, 168, 48, 255), new Color(255, 255, 255, 255), async () => {
                    this._doubleClaimed = true;
                    await this.controller?.claimDoubleRewardWithAd();
                    this._rebuildModal();
                }, 21).node.setPosition(0, -76, 0);
            }

            this._makeButton(
                'NextBtn',
                card,
                440,
                74,
                s.playMode === 'level' && s.level && s.level.id < TOTAL_LEVELS ? 'Next Level' : 'Play Again',
                new Color(116, 72, 245, 255),
                new Color(255, 255, 255, 255),
                () => {
                    this._modal = 'none';
                    this._rebuildModal();
                    if (s.playMode === 'level' && s.level && s.level.id < TOTAL_LEVELS) {
                        this.controller?.startLevel(s.level.id + 1);
                    } else {
                        this.controller?.resetCurrent();
                    }
                },
                24,
            ).node.setPosition(0, -172, 0);
            return;
        }

        if (this._modal === 'skins') {
            this._makeLabel('Title', card, 'Jelly Boutique', 28, new Color(56, 34, 72, 255), 320, 42).node.setPosition(-120, 300, 0);
            this._makeButton('CloseX', card, 50, 50, '✕', new Color(240, 232, 248, 255), new Color(62, 42, 78, 255), () => {
                this._modal = 'none';
                this._rebuildModal();
            }, 22).node.setPosition(265, 300, 0);

            const cats: Array<{ id: 'all' | JellySkinCategory; label: string; x: number }> = [
                { id: 'all', label: 'All', x: -205 },
                { id: 'jelly', label: 'Jelly', x: -68 },
                { id: 'art', label: 'AI Art', x: 68 },
                { id: 'fx', label: 'FX', x: 205 },
            ];
            for (const c of cats) {
                const act = this._skinCat === c.id;
                this._makeButton(
                    `Cat_${c.id}`,
                    card,
                    126,
                    44,
                    c.label,
                    act ? new Color(116, 72, 245, 255) : new Color(240, 232, 248, 255),
                    act ? new Color(255, 255, 255, 255) : new Color(62, 42, 78, 255),
                    () => {
                        this._skinCat = c.id;
                        this._rebuildModal();
                    },
                    18,
                ).node.setPosition(c.x, 235, 0);
            }

            const filtered =
                this._skinCat === 'all'
                    ? JELLY_SKINS
                    : JELLY_SKINS.filter((sk) => sk.category === this._skinCat);

            filtered.slice(0, 6).forEach((skin, idx) => {
                const col = idx % 2;
                const row = Math.floor(idx / 2);
                const x = col === 0 ? -145 : 145;
                const y = 125 - row * 145;
                const unlocked = s.unlockedSkins.includes(skin.id);
                const active = s.activeSkinId === skin.id;
                const status = active ? 'Equipped' : unlocked ? 'Use Skin' : `${skin.cost} Sugar`;

                this._makeButton(
                    `Skin_${skin.id}`,
                    card,
                    268,
                    124,
                    `${skin.name}\n${skin.tag} · ${status}`,
                    active ? new Color(116, 72, 245, 255) : new Color(242, 234, 248, 255),
                    active ? new Color(255, 255, 255, 255) : new Color(58, 38, 74, 255),
                    () => {
                        this.controller?.selectOrUnlockSkin(skin.id);
                        this._rebuildModal();
                    },
                    19,
                ).node.setPosition(x, y, 0);
            });
            return;
        }

        if (this._modal === 'leaderboard') {
            this._makeLabel('Title', card, 'Global Leaderboard', 28, new Color(56, 34, 72, 255), 340, 42).node.setPosition(-110, 300, 0);
            this._makeButton('CloseX', card, 50, 50, '✕', new Color(240, 232, 248, 255), new Color(62, 42, 78, 255), () => {
                this._modal = 'none';
                this._rebuildModal();
            }, 22).node.setPosition(265, 300, 0);

            CHALLENGE_SIZES.forEach((sz, idx) => {
                const act = this._lbSize === sz;
                this._makeButton(
                    `Tab_${sz}`,
                    card,
                    108,
                    44,
                    `${sz}×${sz}`,
                    act ? new Color(116, 72, 245, 255) : new Color(240, 232, 248, 255),
                    act ? new Color(255, 255, 255, 255) : new Color(62, 42, 78, 255),
                    () => {
                        this._lbSize = sz;
                        this._rebuildModal();
                    },
                    18,
                ).node.setPosition(-230 + idx * 115, 235, 0);
            });

            const localLb = getGlobalLeaderboard(this._lbSize, s.playerName, s.bestRecords[this._lbSize]);
            const rowsNode = new Node('Rows');
            rowsNode.parent = card;
            const renderRows = (entries: typeof localLb.entries) => {
                rowsNode.removeAllChildren();
                entries.slice(0, 6).forEach((e, idx) => {
                    this._makeLabel(
                        `Row_${idx}`,
                        rowsNode,
                        `#${e.rank}  ${e.name} (${e.region})  —  ${formatDurationMs(e.timeMs)} · ${e.moves}m`,
                        19,
                        e.isPlayer ? new Color(116, 72, 245, 255) : new Color(62, 42, 78, 255),
                        540,
                        42,
                    ).node.setPosition(0, 145 - idx * 54, 0);
                });
            };
            renderRows(localLb.entries);
            fetchGlobalLeaderboard(this._lbSize, s.playerId, s.playerName, s.bestRecords[this._lbSize]).then(
                (live) => {
                    if (this._modal === 'leaderboard' && rowsNode.isValid) {
                        renderRows(live.entries);
                    }
                },
            );

            const rec = getRecommendedChallenge(s.unlockedLevel);
            this._makeButton(
                'StartRace',
                card,
                460,
                70,
                `Start ${this._lbSize}×${this._lbSize} Race (${rec.size}×${rec.size} Pick)`,
                new Color(116, 72, 245, 255),
                new Color(255, 255, 255, 255),
                () => {
                    this._modal = 'none';
                    this._rebuildModal();
                    this.controller?.startChallenge(this._lbSize);
                },
                22,
            ).node.setPosition(0, -255, 0);
            return;
        }

        if (this._modal === 'levels') {
            this._makeLabel('Title', card, 'Select Level (1–30)', 28, new Color(56, 34, 72, 255), 360, 42).node.setPosition(-80, 300, 0);
            this._makeButton('CloseX', card, 50, 50, '✕', new Color(240, 232, 248, 255), new Color(62, 42, 78, 255), () => {
                this._modal = 'none';
                this._rebuildModal();
            }, 22).node.setPosition(265, 300, 0);

            for (let i = 1; i <= 20; i++) {
                const col = (i - 1) % 5;
                const row = Math.floor((i - 1) / 5);
                const x = -220 + col * 110;
                const y = 190 - row * 105;
                const unlocked = i <= s.unlockedLevel;
                const stars = s.levelStars[i] ?? 0;
                this._makeButton(
                    `Lvl_${i}`,
                    card,
                    92,
                    86,
                    unlocked ? `${i}\n${'★'.repeat(stars)}` : `${i}\n🔒`,
                    unlocked ? new Color(240, 232, 248, 255) : new Color(235, 235, 238, 255),
                    unlocked ? new Color(62, 42, 78, 255) : new Color(150, 150, 160, 255),
                    () => {
                        if (!unlocked) return;
                        this._modal = 'none';
                        this._rebuildModal();
                        this.controller?.startLevel(i);
                    },
                    19,
                ).node.setPosition(x, y, 0);
            }
        }
    }
}
