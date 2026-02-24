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
