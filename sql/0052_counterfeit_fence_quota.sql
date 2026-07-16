-- 0052_counterfeit_fence_quota.sql — persist the per-character-per-fence-per-day
-- counterfeit cash-out quota. It was an in-memory counter, so every server
-- restart reset it to zero and the daily cap could be re-hit after each reboot
-- (a money faucet on a frequently-restarting server). The quota is now written
-- on each fence attempt and rehydrated at boot.
--
-- IDEMPOTENT (CREATE TABLE IF NOT EXISTS) — safe to re-run every boot, so it is
-- also embedded in palm6_dbmigrate (no ledger; CI never touches the DB).

CREATE TABLE IF NOT EXISTS `palm6_counterfeit_fence_quota` (
    `cid`      VARCHAR(64) NOT NULL,
    `fence_id` VARCHAR(64) NOT NULL,
    `day_key`  VARCHAR(8)  NOT NULL,
    `cnt`      INT         NOT NULL DEFAULT 0,
    PRIMARY KEY (`cid`, `fence_id`, `day_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
