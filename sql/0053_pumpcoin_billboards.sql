-- 0053_pumpcoin_billboards.sql — persist paid /pumpboard billboards. They were
-- stored only in memory, so a restart within a billboard's 30-minute window
-- silently destroyed a paid $2,500 blip with no refund. Now written on purchase
-- and rehydrated at boot (expired rows pruned).
--
-- IDEMPOTENT (CREATE TABLE IF NOT EXISTS) — safe to re-run every boot, so it is
-- also embedded in palm6_dbmigrate (no ledger; CI never touches the DB).

CREATE TABLE IF NOT EXISTS `palm6_pumpcoin_billboards` (
    `id`         INT         NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `coord_x`    DOUBLE      NOT NULL,
    `coord_y`    DOUBLE      NOT NULL,
    `coord_z`    DOUBLE      NOT NULL,
    `label`      VARCHAR(64) NOT NULL,
    `expires_at` BIGINT      NOT NULL,
    INDEX `idx_palm6_pumpcoin_billboards_exp` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
