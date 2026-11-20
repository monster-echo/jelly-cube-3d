// Cloudflare Worker + D1 Global Leaderboard API for Jelly Cube 3D
// Deploy:
//   npx wrangler d1 create jelly_cube_3d_lb
//   npx wrangler d1 execute jelly_cube_3d_lb --file=schema.sql
//   npx wrangler deploy

export interface Env {
    DB: D1Database;
}

const VALID_SIZES = new Set([3, 4, 5, 9, 10]);

const CORS_HEADERS = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
};

function json(data: unknown, status = 200): Response {
    return new Response(JSON.stringify(data), {
        status,
        headers: { 'Content-Type': 'application/json; charset=utf-8', ...CORS_HEADERS },
    });
}

export default {
    async fetch(request: Request, env: Env): Promise<Response> {
        if (request.method === 'OPTIONS') {
            return new Response(null, { status: 204, headers: CORS_HEADERS });
        }

        const url = new URL(request.url);

        if (request.method === 'GET' && url.pathname === '/api/leaderboard') {
            const size = Number(url.searchParams.get('size') || '3');
            if (!VALID_SIZES.has(size)) {
                return json({ error: 'Invalid cube size' }, 400);
            }
            const { results } = await env.DB.prepare(
                'SELECT player_id, name, region, time_ms, moves FROM leaderboard_scores WHERE size = ? ORDER BY time_ms ASC, moves ASC LIMIT 50',
            )
                .bind(size)
                .all();
            return json({ size, entries: results ?? [] });
        }

        if (request.method === 'POST' && url.pathname === '/api/score') {
            const body = (await request.json().catch(() => null)) as {
                size?: number;
                playerId?: string;
                name?: string;
                region?: string;
                timeMs?: number;
                moves?: number;
            } | null;

            if (!body || !VALID_SIZES.has(Number(body.size))) {
                return json({ error: 'Invalid size' }, 400);
            }
            const size = Number(body.size);
            const playerId = String(body.playerId || '').slice(0, 64).trim();
            const name = String(body.name || '果冻玩家').slice(0, 24).trim() || '果冻玩家';
            const region = String(body.region || (request.cf?.country as string) || 'CN')
                .slice(0, 4)
                .toUpperCase();
            const timeMs = Math.round(Number(body.timeMs));
            const moves = Math.round(Number(body.moves));

            if (!playerId || !Number.isFinite(timeMs) || timeMs < 300 || !Number.isFinite(moves) || moves < 1) {
                return json({ error: 'Invalid score payload' }, 400);
            }

            // Upsert keeping the player's best time for this cube size
            await env.DB.prepare(
                `INSERT INTO leaderboard_scores (size, player_id, name, region, time_ms, moves, created_at)
                 VALUES (?, ?, ?, ?, ?, ?, ?)
                 ON CONFLICT(size, player_id) DO UPDATE SET
                   name = excluded.name,
                   region = excluded.region,
                   time_ms = MIN(leaderboard_scores.time_ms, excluded.time_ms),
                   moves = CASE WHEN excluded.time_ms < leaderboard_scores.time_ms THEN excluded.moves ELSE leaderboard_scores.moves END,
                   created_at = excluded.created_at`,
            )
                .bind(size, playerId, name, region, timeMs, moves, Date.now())
                .run();

            return json({ ok: true });
        }

        return json({ error: 'Not found' }, 404);
    },
};
