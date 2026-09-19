-- TradePulse Phase 3 persistence sketch (PostgreSQL-ready).
-- Runtime currently uses in-memory stores with the same fields.

CREATE TABLE IF NOT EXISTS users (
    user_id TEXT PRIMARY KEY,
    email TEXT UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS demo_accounts (
    user_id TEXT PRIMARY KEY REFERENCES users(user_id),
    balance NUMERIC(18, 2) NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS demo_trades (
    trade_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    asset TEXT NOT NULL,
    direction TEXT NOT NULL,
    stake NUMERIC(18, 2) NOT NULL,
    entry_price NUMERIC(18, 8) NOT NULL,
    entry_time TIMESTAMPTZ NOT NULL,
    expiry_time TIMESTAMPTZ NOT NULL,
    expiry_price NUMERIC(18, 8),
    payout_rate NUMERIC(8, 4) NOT NULL,
    result TEXT,
    profit_loss NUMERIC(18, 2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS signals (
    signal_id TEXT PRIMARY KEY,
    asset TEXT NOT NULL,
    direction TEXT NOT NULL,
    generated_at TIMESTAMPTZ NOT NULL,
    entry_price NUMERIC(18, 8) NOT NULL,
    expiry_time TIMESTAMPTZ NOT NULL,
    confidence NUMERIC(8, 4) NOT NULL,
    status TEXT NOT NULL,
    source TEXT NOT NULL,
    result TEXT
);

CREATE TABLE IF NOT EXISTS candles (
    asset TEXT NOT NULL,
    open_time TIMESTAMPTZ NOT NULL,
    close_time TIMESTAMPTZ NOT NULL,
    open NUMERIC(18, 8) NOT NULL,
    high NUMERIC(18, 8) NOT NULL,
    low NUMERIC(18, 8) NOT NULL,
    close NUMERIC(18, 8) NOT NULL,
    volume INTEGER NOT NULL,
    closed BOOLEAN NOT NULL,
    PRIMARY KEY (asset, open_time)
);

CREATE TABLE IF NOT EXISTS market_state (
    asset TEXT PRIMARY KEY,
    price NUMERIC(18, 8) NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);
