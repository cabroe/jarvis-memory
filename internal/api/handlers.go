package api

import (
	"encoding/json"
	"net/http"

	"github.com/labstack/echo/v5"

	"jarvis-memory/internal/db"
	"jarvis-memory/internal/embeddings"
)

type Handler struct {
	db  *db.DB
	emb *embeddings.Service
}

func NewHandler(d *db.DB, e *embeddings.Service) *Handler {
	return &Handler{db: d, emb: e}
}

func (h *Handler) RegisterRoutes(e *echo.Echo) {
	e.POST("/seeds", h.HandleCreateSeed)
	e.POST("/seeds/query", h.HandleQuerySeeds)
	e.POST("/agent-contexts", h.HandleCreateAgentContext)
	e.GET("/agent-contexts", h.HandleGetAgentContexts)
	e.GET("/agent-contexts/:id", h.HandleGetAgentContext)
}

func (h *Handler) HandleCreateSeed(c *echo.Context) error {
	content := c.FormValue("content")
	title := c.FormValue("title")
	typ := c.FormValue("type")

	if content == "" || title == "" || typ == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "content, title, and type are required"})
	}

	emb, err := h.emb.Embed(content)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to embed content"})
	}

	seed := &db.Seed{
		Content: content,
		Title:   title,
		Type:    typ,
	}

	if err := h.db.InsertSeed(c.Request().Context(), seed, emb); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusCreated, seed)
}

type QuerySeedsRequest struct {
	Query     string  `json:"query"`
	Limit     int     `json:"limit"`
	Threshold float32 `json:"threshold"`
}

func (h *Handler) HandleQuerySeeds(c *echo.Context) error {
	var req QuerySeedsRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid json"})
	}

	if req.Query == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "query is required"})
	}

	emb, err := h.emb.Embed(req.Query)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to embed query"})
	}

	if req.Limit <= 0 {
		req.Limit = 10
	}
	// Allow 0.0 as a valid threshold
	if req.Threshold < 0 {
		req.Threshold = 0.5
	}

	results, err := h.db.SearchSeeds(c.Request().Context(), emb, req.Limit, req.Threshold)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	if results == nil {
		results = []db.SeedSearchResult{}
	}

	return c.JSON(http.StatusOK, results)
}

type CreateAgentContextRequest struct {
	AgentID  string          `json:"agentId"`
	Type     string          `json:"type"`
	Metadata json.RawMessage `json:"metadata"`
	Summary  string          `json:"summary"`
}

func (h *Handler) HandleCreateAgentContext(c *echo.Context) error {
	var req CreateAgentContextRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid json"})
	}

	if req.AgentID == "" || req.Type == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "agentId and type are required"})
	}

	// For agent context, we typically embed the summary or stringified metadata
	// The prompt implies the agent-context might just embed a combination.
	// Let's combine summary and type to create an embedding, or just stringify the JSON.
	textToEmbed := req.Summary
	if textToEmbed == "" {
		if len(req.Metadata) > 0 {
			textToEmbed = string(req.Metadata)
		} else {
			textToEmbed = req.Type // fallback
		}
	}

	emb, err := h.emb.Embed(textToEmbed)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to embed agent context"})
	}

	ac := &db.AgentContext{
		AgentID:  req.AgentID,
		Type:     req.Type,
		Metadata: req.Metadata,
		Summary:  req.Summary,
	}

	if err := h.db.InsertAgentContext(c.Request().Context(), ac, emb); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusCreated, ac)
}

func (h *Handler) HandleGetAgentContexts(c *echo.Context) error {
	agentID := c.QueryParam("agentId")
	
	results, err := h.db.GetAgentContexts(c.Request().Context(), agentID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	if results == nil {
		results = []db.AgentContext{}
	}

	return c.JSON(http.StatusOK, results)
}

func (h *Handler) HandleGetAgentContext(c *echo.Context) error {
	id := c.Param("id")
	
	ac, err := h.db.GetAgentContextByID(c.Request().Context(), id)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	if ac == nil {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "agent context not found"})
	}

	return c.JSON(http.StatusOK, ac)
}
