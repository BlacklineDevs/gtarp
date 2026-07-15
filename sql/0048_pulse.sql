-- 0048_pulse.sql — palm6_pulse (live city director + modifier bus)
-- Windows are authoritative here; "active" = newest row where ends_at > now.
-- Restart-safe: the director rehydrates the active window from this table on boot.
-- All IF NOT EXISTS (re-run safe). Also embedded in palm6_dbmigrate for prod,
-- since CI never touches the DB.

CREATE TABLE IF NOT EXISTS `palm6_pulse_windows` (
    id            INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
    kind          VARCHAR(32)  NOT NULL,           -- boomtown|hot_exchange|bounty_surge|crackdown|turf_war
    domain        VARCHAR(16)  NOT NULL,           -- grind|market|bounty|police|gang
    modifier      DOUBLE       NOT NULL,           -- capped payout scalar
    target        VARCHAR(64)  NULL,               -- optional sub-key (e.g. spiked commodity)
    reason        VARCHAR(128) NOT NULL,
    online_start  INT          NOT NULL DEFAULT 0,
    started_at    BIGINT       NOT NULL,
    ends_at       BIGINT       NOT NULL,
    INDEX idx_palm6_pulse_windows_ends (ends_at)
);

CREATE TABLE IF NOT EXISTS `palm6_pulse_checkins` (
    id          INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
    window_id   INT          NOT NULL,
    citizenid   VARCHAR(64)  NOT NULL,
    ts          BIGINT       NOT NULL,
    UNIQUE KEY uq_palm6_pulse_checkin (window_id, citizenid),  -- the consume/idempotency gate
    INDEX idx_palm6_pulse_checkins_cid (citizenid)
);

CREATE TABLE IF NOT EXISTS `palm6_pulse_streaks` (
    citizenid       VARCHAR(64) NOT NULL PRIMARY KEY,
    streak          INT         NOT NULL DEFAULT 0,
    best_streak     INT         NOT NULL DEFAULT 0,
    pulse_points    INT         NOT NULL DEFAULT 0,   -- lifetime; feeds the season scoreboard, no cash value
    last_window_id  INT         NOT NULL DEFAULT 0,
    updated_at      BIGINT      NOT NULL DEFAULT 0
);
