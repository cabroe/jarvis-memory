package admin

import (
	"context"
	"database/sql"
	_ "embed"
	"html/template"
	"io"
	"net/http"
	"time"

	"github.com/labstack/echo/v5"

	"jarvis-memory/internal/db"
)

//go:embed templates/index.html
var indexHTML string

type Renderer struct {
	templates *template.Template
}

func (r *Renderer) Render(c *echo.Context, w io.Writer, name string, data interface{}) error {
	return r.templates.ExecuteTemplate(w, name, data)
}

type AdminHandler struct {
	db *db.DB
}

func NewHandler(dbConn *db.DB) *AdminHandler {
	return &AdminHandler{db: dbConn}
}

func (h *AdminHandler) RegisterRoutes(e *echo.Echo) {
	t := &Renderer{
		templates: template.Must(template.New("index.html").Funcs(template.FuncMap{
			"truncate": func(s string, l int) string {
				if len(s) > l {
					return s[:l] + "..."
				}
				return s
			},
			"mul": func(a float32, b float64) float64 {
				return float64(a) * b
			},
			"ge": func(a float32, b float64) bool {
				return float64(a) >= b
			},
		}).Parse(indexHTML)),
	}
	e.Renderer = t

	e.GET("/admin", h.HandleAdmin)
}


type AdminData struct {
	Seeds         []db.Seed
	AgentContexts []db.AgentContext
}

func (h *AdminHandler) HandleAdmin(c *echo.Context) error {
	ctx := c.Request().Context()

	seeds, err := h.getLatestSeeds(ctx)
	if err != nil {
		return c.String(http.StatusInternalServerError, "Failed to load seeds: "+err.Error())
	}

	contexts, err := h.getLatestAgentContexts(ctx)
	if err != nil {
		return c.String(http.StatusInternalServerError, "Failed to load agent contexts: "+err.Error())
	}

	data := AdminData{
		Seeds:         seeds,
		AgentContexts: contexts,
	}

	return c.Render(http.StatusOK, "index.html", data)
}

func (h *AdminHandler) getLatestSeeds(ctx context.Context) ([]db.Seed, error) {
	query := `SELECT id, content, title, type, confidence, last_accessed, created_at FROM seeds ORDER BY created_at DESC LIMIT 100`
	rows, err := h.db.QueryContext(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var seeds []db.Seed
	for rows.Next() {
		var s db.Seed
		var lastAccessed sql.NullTime
		if err := rows.Scan(&s.ID, &s.Content, &s.Title, &s.Type, &s.Confidence, &lastAccessed, &s.CreatedAt); err != nil {
			return nil, err
		}
		if lastAccessed.Valid {
			s.LastAccessed = lastAccessed.Time
		} else {
			s.LastAccessed = time.Time{}
		}
		seeds = append(seeds, s)
	}
	return seeds, nil
}

func (h *AdminHandler) getLatestAgentContexts(ctx context.Context) ([]db.AgentContext, error) {
	return h.db.GetAgentContexts(ctx, "")
}
