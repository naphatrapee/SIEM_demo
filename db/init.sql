-- Events table, partitioned by day (retention = drop old partitions)
CREATE TABLE events (
    id            BIGSERIAL,
    ts            TIMESTAMPTZ NOT NULL,          -- @timestamp
    tenant        TEXT NOT NULL,
    source        TEXT NOT NULL,                 -- firewall|crowdstrike|aws|m365|ad|api|network
    vendor        TEXT,
    product       TEXT,
    event_type    TEXT,
    event_subtype TEXT,
    severity      SMALLINT DEFAULT 0,            -- 0-10
    action        TEXT,                          -- allow|deny|create|delete|login|logout|alert
    src_ip        INET,
    src_port      INTEGER,
    dst_ip        INET,
    dst_port      INTEGER,
    protocol      TEXT,
    user_name     TEXT,
    host          TEXT,
    process       TEXT,
    url           TEXT,
    http_method   TEXT,
    status_code   INTEGER,
    rule_name     TEXT,
    rule_id       TEXT,
    cloud         JSONB,                         -- account_id, region, service
    raw           TEXT,
    tags          TEXT[] DEFAULT '{}',
    extra         JSONB DEFAULT '{}',
    PRIMARY KEY (id, ts)
) PARTITION BY RANGE (ts);

CREATE INDEX idx_events_tenant_ts ON events (tenant, ts DESC);
CREATE INDEX idx_events_source    ON events (tenant, source, ts DESC);
CREATE INDEX idx_events_src_ip    ON events (src_ip);
CREATE INDEX idx_events_user      ON events (user_name);
CREATE INDEX idx_events_extra_gin ON events USING GIN (extra);

-- Helper used by init and by the worker (daily job)
CREATE OR REPLACE FUNCTION ensure_partition(d DATE) RETURNS VOID AS $$
DECLARE pname TEXT := 'events_' || to_char(d, 'YYYYMMDD');
BEGIN
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS %I PARTITION OF events FOR VALUES FROM (%L) TO (%L)',
        pname, d, d + 1);
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION drop_old_partitions(keep_days INT) RETURNS VOID AS $$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT c.relname FROM pg_inherits i
             JOIN pg_class c ON c.oid = i.inhrelid
             JOIN pg_class p ON p.oid = i.inhparent
             WHERE p.relname = 'events'
               AND c.relname < 'events_' || to_char(current_date - keep_days, 'YYYYMMDD')
    LOOP
        EXECUTE format('DROP TABLE IF EXISTS %I', r.relname);
    END LOOP;
END $$ LANGUAGE plpgsql;

-- Pre-create partitions: 8 days back to 2 days ahead (sample data + safety margin)
SELECT ensure_partition(current_date + g) FROM generate_series(-8, 2) g;

CREATE TABLE users (
    id            SERIAL PRIMARY KEY,
    username      TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role          TEXT NOT NULL CHECK (role IN ('admin','viewer')),
    tenant        TEXT                            -- NULL = admin (all tenants)
);

CREATE TABLE alert_rules (
    id                SERIAL PRIMARY KEY,
    name              TEXT NOT NULL,
    tenant            TEXT,                       -- NULL = all tenants
    threshold         INTEGER NOT NULL DEFAULT 5,
    window_minutes    INTEGER NOT NULL DEFAULT 5,
    webhook_url       TEXT,
    enabled           BOOLEAN DEFAULT TRUE
);

CREATE TABLE alerts (
    id          BIGSERIAL PRIMARY KEY,
    rule_id     INTEGER REFERENCES alert_rules(id),
    tenant      TEXT NOT NULL,
    fired_at    TIMESTAMPTZ DEFAULT now(),
    src_ip      INET,
    count       INTEGER,
    message     TEXT,
    notified    BOOLEAN DEFAULT FALSE
);
CREATE INDEX idx_alerts_tenant ON alerts (tenant, fired_at DESC);

INSERT INTO alert_rules (name, threshold, window_minutes)
VALUES ('Repeated failed logins from same IP', 5, 5);

-- TODO: Row-Level Security policies (optional second layer of tenant isolation)
-- Users are seeded by the backend on startup (bcrypt hashes from .env passwords)
