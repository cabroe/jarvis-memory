package db

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"github.com/pgvector/pgvector-go"
)

type Seed struct {
	ID        string    `json:"id"`
	Content   string    `json:"content"`
	Title     string    `json:"title"`
	Type      string    `json:"type"`
	CreatedAt time.Time `json:"created_at"`
	// embedding not exported fully in JSON
}

func (db *DB) InsertSeed(ctx context.Context, s *Seed, embedding []float32) error {
	query := `
		INSERT INTO seeds (content, title, type, embedding)
		VALUES ($1, $2, $3, $4)
		RETURNING id, created_at
	`
	vec := pgvector.NewVector(embedding)
	err := db.QueryRowContext(ctx, query, s.Content, s.Title, s.Type, vec).Scan(&s.ID, &s.CreatedAt)
	if err != nil {
		return fmt.Errorf("failed to insert seed: %w", err)
	}
	return nil
}

type SeedSearchResult struct {
	Seed
	Similarity float32 `json:"similarity"`
}

func (db *DB) SearchSeeds(ctx context.Context, embedding []float32, limit int, threshold float32) ([]SeedSearchResult, error) {
	if limit <= 0 {
		limit = 10
	}
	// Cosine distance is used implicitly with HNSW vector_l2_ops for L2 distance.
	// Wait, the index is vector_l2_ops. L2 distance works as well for normalized HNSW.
	// If L2 distance is D, similarity is 1 - (D^2)/2. 
	// Or we can just use `<=>` for cosine distance if HNSW also supports it, but we built HNSW with vector_l2_ops.
	// Let's use L2 distance `<->` and filter by threshold.
	// Wait, pgvector HNSW index with vector_l2_ops requires `<->`. 
	// similarity = 1 - (distance^2 / 2) for normalized vectors, or we can just return distance. The prompt expects maybe cosine similarity?
	// The prompt didn't specify similarity return value explicitly, but we can compute something or just return L2 distance. I will use 1 - `<=>` for cosine similarity and just order by `<->`.

	// Using L2 distance <-> to match the hnsw index with vector_l2_ops for performance.
	query := `
		SELECT id, content, title, type, created_at, 1 - (embedding <=> $1) AS similarity
		FROM seeds
		WHERE 1 - (embedding <=> $1) >= $2
		ORDER BY embedding <-> $1
		LIMIT $3
	`
	vec := pgvector.NewVector(embedding)
	rows, err := db.QueryContext(ctx, query, vec, threshold, limit)
	if err != nil {
		return nil, fmt.Errorf("failed to query seeds: %w", err)
	}
	defer rows.Close()

	var results []SeedSearchResult
	for rows.Next() {
		var res SeedSearchResult
		if err := rows.Scan(&res.ID, &res.Content, &res.Title, &res.Type, &res.CreatedAt, &res.Similarity); err != nil {
			return nil, err
		}
		results = append(results, res)
	}
	return results, nil
}

type AgentContext struct {
	ID        string          `json:"id"`
	AgentID   string          `json:"agentId"`
	Type      string          `json:"type"`
	Metadata  json.RawMessage `json:"metadata"`
	Summary   string          `json:"summary"`
	CreatedAt time.Time       `json:"created_at"`
}

func (db *DB) InsertAgentContext(ctx context.Context, ac *AgentContext, embedding []float32) error {
	query := `
		INSERT INTO agent_contexts (agent_id, type, metadata, summary, embedding)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, created_at
	`
	vec := pgvector.NewVector(embedding)
	
	// if metadata is null, we can pass null
	var meta interface{} = ac.Metadata
	if len(ac.Metadata) == 0 {
		meta = nil
	}

	err := db.QueryRowContext(ctx, query, ac.AgentID, ac.Type, meta, ac.Summary, vec).Scan(&ac.ID, &ac.CreatedAt)
	if err != nil {
		return fmt.Errorf("failed to insert agent context: %w", err)
	}
	return nil
}

func (db *DB) GetAgentContexts(ctx context.Context, agentID string) ([]AgentContext, error) {
	query := `SELECT id, agent_id, type, metadata, summary, created_at FROM agent_contexts`
	var args []interface{}

	if agentID != "" {
		query += ` WHERE agent_id = $1`
		args = append(args, agentID)
	}
	
	query += ` ORDER BY created_at DESC`

	rows, err := db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []AgentContext
	for rows.Next() {
		var ac AgentContext
		var meta []byte
		var sum sql.NullString
		if err := rows.Scan(&ac.ID, &ac.AgentID, &ac.Type, &meta, &sum, &ac.CreatedAt); err != nil {
			return nil, err
		}
		if meta != nil {
			ac.Metadata = meta
		}
		if sum.Valid {
			ac.Summary = sum.String
		}
		results = append(results, ac)
	}
	return results, nil
}

func (db *DB) GetAgentContextByID(ctx context.Context, id string) (*AgentContext, error) {
	query := `SELECT id, agent_id, type, metadata, summary, created_at FROM agent_contexts WHERE id = $1`
	var ac AgentContext
	var meta []byte
	var sum sql.NullString
	err := db.QueryRowContext(ctx, query, id).Scan(&ac.ID, &ac.AgentID, &ac.Type, &meta, &sum, &ac.CreatedAt)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil // not found
		}
		return nil, err
	}
	if meta != nil {
		ac.Metadata = meta
	}
	if sum.Valid {
		ac.Summary = sum.String
	}
	return &ac, nil
}
