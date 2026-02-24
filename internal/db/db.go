package db

import (
	"context"
	"database/sql"
	"fmt"
	"log"

	_ "github.com/lib/pq"
)

type DB struct {
	*sql.DB
}

func Connect(connStr string) (*DB, error) {
	db, err := sql.Open("postgres", connStr)
	if err != nil {
		return nil, fmt.Errorf("failed to open db connection: %w", err)
	}

	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("failed to ping db: %w", err)
	}

	return &DB{db}, nil
}

func (db *DB) AutoMigrate(ctx context.Context) error {
	log.Println("Running AutoMigrate...")

	queries := []string{
		`CREATE EXTENSION IF NOT EXISTS vector;`,

		`CREATE TABLE IF NOT EXISTS seeds (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			content TEXT NOT NULL,
			title TEXT NOT NULL,
			type VARCHAR(50) NOT NULL,
			embedding vector(384),
			created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
		);`,

		`CREATE INDEX IF NOT EXISTS seeds_embedding_idx ON seeds USING hnsw (embedding vector_l2_ops);`,

		// New columns for confidence and decay tracking
		`ALTER TABLE seeds ADD COLUMN IF NOT EXISTS confidence REAL NOT NULL DEFAULT 1.0;`,
		`ALTER TABLE seeds ADD COLUMN IF NOT EXISTS last_accessed TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;`,

		`CREATE TABLE IF NOT EXISTS agent_contexts (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			agent_id VARCHAR(255) NOT NULL,
			type VARCHAR(50) NOT NULL,
			metadata JSONB,
			summary TEXT,
			embedding vector(384),
			created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
		);`,

		`CREATE INDEX IF NOT EXISTS agent_contexts_embedding_idx ON agent_contexts USING hnsw (embedding vector_l2_ops);`,
	}

	for i, q := range queries {
		log.Printf("Running migration %d...", i+1)
		if _, err := db.ExecContext(ctx, q); err != nil {
			return fmt.Errorf("failed to execute migration %d: %w", i+1, err)
		}
	}

	log.Println("Database migration completed.")
	return nil
}

// ApplyDecay reduces confidence for old, low-confidence seeds.
// Seeds older than 90 days with confidence < 0.3 get their confidence reduced by 10%.
func (db *DB) ApplyDecay(ctx context.Context) error {
	log.Println("Applying memory decay...")

	query := `
		UPDATE seeds
		SET confidence = confidence * 0.9
		WHERE created_at < NOW() - INTERVAL '90 days'
		  AND confidence < 0.3
		  AND confidence > 0.01
	`

	result, err := db.ExecContext(ctx, query)
	if err != nil {
		return fmt.Errorf("failed to apply decay: %w", err)
	}

	rows, _ := result.RowsAffected()
	log.Printf("Decay applied to %d seeds.", rows)
	return nil
}
