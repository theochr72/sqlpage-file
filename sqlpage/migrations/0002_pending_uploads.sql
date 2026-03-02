-- 0002_pending_uploads.sql — Table for tracking uploaded PDFs awaiting processing

CREATE TABLE IF NOT EXISTS accounting.pending_upload (
    id          SERIAL PRIMARY KEY,
    filename    TEXT NOT NULL,
    file_path   TEXT NOT NULL,
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    processed   BOOLEAN NOT NULL DEFAULT FALSE
);
