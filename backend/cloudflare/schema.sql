-- Cloudflare D1 Schema for Jelly Cube 3D Global Leaderboard
CREATE TABLE IF NOT EXISTS leaderboard_scores (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  size INTEGER NOT NULL,
  player_id TEXT NOT NULL,
  name TEXT NOT NULL,
  region TEXT NOT NULL DEFAULT 'CN',
  time_ms INTEGER NOT NULL,
  moves INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_lb_size_time ON leaderboard_scores (size, time_ms ASC, moves ASC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_lb_player_size ON leaderboard_scores (size, player_id);
