// Jelly Cube 3D — Curated Boutique Jelly Skins, AI Art Packs & Special FX Materials.

export type JellyMaterialMode = 'jelly' | 'plush' | 'liquid' | 'sand';
export type JellySkinCategory = 'jelly' | 'art' | 'fx';

export interface JellyMaterialParams {
    /** Shader surface mode: jelly (default), plush, liquid, or sand. */
    mode?: JellyMaterialMode;
    /** Translucency / subsurface wrap (0 = opaque pudding, 1 = crystal jelly). */
    wrapLight: number;
    /** Fresnel rim intensity. */
    rimStrength: number;
    /** Fresnel power (higher = tighter edge highlight). */
    rimPower: number;
    /** Specular shininess. */
    shininess: number;
    /** Alpha opacity for jelly body (0.80..1.0). */
    alpha: number;
    /** Optional emissive glow tint [r, g, b]. */
    emissive: readonly [number, number, number];
}

export type JellyPatternKind = 'none';

export interface JellySkinDef {
    id: string;
    name: string;
    subtitle: string;
    category: JellySkinCategory;
    tag: string;
    cost: number;
    /** 6 face colors in [U, D, F, B, R, L] order as hex RGB strings. */
    colors: readonly [string, string, string, string, string, string];
    /** Background studio gradient top/bottom hex. */
    backdropTop: string;
    backdropBottom: string;
    material: JellyMaterialParams;
    pattern?: JellyPatternKind;
    /** Remote or local texture URL (e.g. Cloudflare R2 AI-generated art). */
    remoteTextureUrl?: string;
    /** Optional 6 separate texture URLs for [U, D, F, B, R, L] faces. */
    faceTextureUrls?: readonly [string, string, string, string, string, string];
    /** When true, each face renders as one unified jigsaw picture split across its N×N tiles. */
    wholeFaceJigsaw?: boolean;
}

export const JELLY_SKINS: readonly JellySkinDef[] = [
    {
        id: 'classic',
        name: 'Classic Fruit',
        subtitle: 'Coconut · Lemon · Mint · Sky · Coral · Orange',
        category: 'jelly',
        tag: 'FREE',
        cost: 0,
        colors: ['#FFFDFB', '#FFE338', '#38E56B', '#369EFF', '#FF3F6C', '#FF962E'],
        backdropTop: '#F7EAFF',
        backdropBottom: '#EDD6FC',
        material: {
            wrapLight: 0.54,
            rimStrength: 0.72,
            rimPower: 2.3,
            shininess: 68,
            alpha: 0.90,
            emissive: [0.03, 0.02, 0.04],
        },
    },
    {
        id: 'strawberry_daifuku',
        name: 'Ichigo Daifuku',
        subtitle: 'Japanese watercolor dessert jigsaw',
        category: 'art',
        tag: 'AI ART',
        cost: 120,
        wholeFaceJigsaw: true,
        remoteTextureUrl: './textures/dessert_sticker.png',
        colors: ['#FFF8F4', '#FFE5A3', '#C5ECD0', '#C4E2FF', '#FFB5C8', '#FFD0B5'],
        backdropTop: '#FFF6F4',
        backdropBottom: '#FFE4E8',
        material: {
            wrapLight: 0.48,
            rimStrength: 0.55,
            rimPower: 2.6,
            shininess: 48,
            alpha: 0.96,
            emissive: [0.02, 0.01, 0.02],
        },
    },
    {
        id: 'calico_kitty',
        name: 'Calico Kitty',
        subtitle: 'Chibi picture-book kitten jigsaw',
        category: 'art',
        tag: 'AI ART',
        cost: 160,
        wholeFaceJigsaw: true,
        remoteTextureUrl: './textures/pet_sticker.png',
        colors: ['#FFF9FB', '#FFECB3', '#C9F0D8', '#CDE4FF', '#FFC2D9', '#FFD8BE'],
        backdropTop: '#FFF6FA',
        backdropBottom: '#F7E3F0',
        material: {
            wrapLight: 0.46,
            rimStrength: 0.55,
            rimPower: 2.6,
            shininess: 46,
            alpha: 0.96,
            emissive: [0.02, 0.01, 0.02],
        },
    },
    {
        id: 'crystal',
        name: 'Crystal Ice',
        subtitle: 'Glassy translucency & frost rim',
        category: 'jelly',
        tag: 'GLASS',
        cost: 80,
        colors: ['#F7FCFF', '#FFF099', '#5FF0D0', '#5CB3FF', '#FF75B0', '#FFB066'],
        backdropTop: '#EEF8FF',
        backdropBottom: '#DCEEFF',
        material: {
            wrapLight: 0.62,
            rimStrength: 0.80,
            rimPower: 2.2,
            shininess: 82,
            alpha: 0.82,
            emissive: [0.03, 0.04, 0.06],
        },
    },
    {
        id: 'pudding',
        name: 'Caramel Pudding',
        subtitle: 'Creamy pastel & soft custard gloss',
        category: 'jelly',
        tag: 'SOFT',
        cost: 100,
        colors: ['#FFF9EE', '#F7D27A', '#9ED9B0', '#8FB8DE', '#EC8B96', '#F0AC6E'],
        backdropTop: '#FFF8ED',
        backdropBottom: '#F7E7D4',
        material: {
            wrapLight: 0.36,
            rimStrength: 0.45,
            rimPower: 3.0,
            shininess: 34,
            alpha: 0.96,
            emissive: [0.02, 0.02, 0.01],
        },
    },
    {
        id: 'matcha',
        name: 'Uji Matcha',
        subtitle: 'Japanese tea & red bean palette',
        category: 'jelly',
        tag: 'ZEN',
        cost: 140,
        colors: ['#FAF6EC', '#EBD582', '#6FB373', '#608FA8', '#C95A6B', '#D9885B'],
        backdropTop: '#F3F8EE',
        backdropBottom: '#E0EDD8',
        material: {
            wrapLight: 0.40,
            rimStrength: 0.50,
            rimPower: 2.8,
            shininess: 40,
            alpha: 0.94,
            emissive: [0.01, 0.02, 0.01],
        },
    },
    {
        id: 'plush_fleece',
        name: 'Fluffy Plush',
        subtitle: 'Cozy velvet fuzz toy blocks',
        category: 'fx',
        tag: 'PLUSH FX',
        cost: 200,
        colors: ['#FFF7F0', '#FFE08A', '#9ED9A8', '#98C4F0', '#F598B2', '#F7B57E'],
        backdropTop: '#FFF6EE',
        backdropBottom: '#F5E4D6',
        material: {
            mode: 'plush',
            wrapLight: 0.80,
            rimStrength: 0.72,
            rimPower: 1.6,
            shininess: 10,
            alpha: 1.0,
            emissive: [0.03, 0.02, 0.02],
        },
    },
    {
        id: 'ocean_liquid',
        name: 'Liquid Wave',
        subtitle: 'Rippling water & animated caustics',
        category: 'fx',
        tag: 'LIQUID FX',
        cost: 240,
        colors: ['#F2FCFF', '#FFF088', '#52EBC2', '#47A3FF', '#FF66A3', '#FF9F54'],
        backdropTop: '#EBF8FF',
        backdropBottom: '#D6EEFF',
        material: {
            mode: 'liquid',
            wrapLight: 0.60,
            rimStrength: 0.82,
            rimPower: 2.1,
            shininess: 88,
            alpha: 0.84,
            emissive: [0.02, 0.04, 0.06],
        },
    },
    {
        id: 'starlight_sand',
        name: 'Glitter Sand',
        subtitle: 'Flowing quicksand & gold sparkles',
        category: 'fx',
        tag: 'SAND FX',
        cost: 280,
        colors: ['#FFF8FA', '#FFE270', '#7AE8AE', '#7BA8FF', '#FF72B6', '#FFA05C'],
        backdropTop: '#261D38',
        backdropBottom: '#35274F',
        material: {
            mode: 'sand',
            wrapLight: 0.50,
            rimStrength: 0.75,
            rimPower: 2.2,
            shininess: 64,
            alpha: 0.94,
            emissive: [0.05, 0.04, 0.08],
        },
    },
    {
        id: 'nebula',
        name: 'Nebula Glow',
        subtitle: '7-day streak reward · Night glow',
        category: 'fx',
        tag: 'STREAK',
        cost: 320,
        colors: ['#EFEBFF', '#FFD95A', '#47F0C5', '#5C7CFF', '#FF57A8', '#FF8E53'],
        backdropTop: '#1E1933',
        backdropBottom: '#2E2147',
        material: {
            wrapLight: 0.58,
            rimStrength: 0.82,
            rimPower: 2.0,
            shininess: 82,
            alpha: 0.88,
            emissive: [0.07, 0.05, 0.12],
        },
    },
];

export function getSkinById(id: string): JellySkinDef {
    return JELLY_SKINS.find((s) => s.id === id) ?? JELLY_SKINS[0];
}

export function hexToRgbNormalized(hex: string): [number, number, number] {
    const clean = hex.replace('#', '');
    const n = parseInt(clean, 16);
    return [((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255];
}
