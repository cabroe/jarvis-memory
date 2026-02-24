package embeddings

import (
	"fmt"
	"github.com/rcarmo/gte-go/gte"
)

type Service struct {
	model *gte.Model
}

func NewService(modelPath string) (*Service, error) {
	model, err := gte.Load(modelPath)
	if err != nil {
		return nil, fmt.Errorf("failed to load gte model from %s: %w", modelPath, err)
	}

	return &Service{
		model: model,
	}, nil
}

func (s *Service) Embed(text string) ([]float32, error) {
	emb, err := s.model.Embed(text)
	if err != nil {
		return nil, fmt.Errorf("failed to embed text: %w", err)
	}
	return emb, nil
}

func (s *Service) Close() {
	if s.model != nil {
		// gte.Model doesn't have a Close method in the struct or wait, the README says model.Close().
		s.model.Close()
	}
}
