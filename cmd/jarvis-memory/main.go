package main

import (
	"context"
	"log"
	"net/http"
	"os"

	"github.com/labstack/echo/v5"
	"github.com/labstack/echo/v5/middleware"

	"jarvis-memory/internal/admin"
	"jarvis-memory/internal/api"
	"jarvis-memory/internal/db"
	"jarvis-memory/internal/embeddings"
)

func main() {
	log.Println("Starting Jarvis Memory...")

	// 1. Initialize DB
	dbURL := os.Getenv("DB_URL")
	if dbURL == "" {
		dbURL = "postgres://jarvis:memorypass@localhost:5432/jarvis_memory?sslmode=disable"
	}

	dbConn, err := db.Connect(dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	if err := dbConn.AutoMigrate(context.Background()); err != nil {
		log.Fatalf("Failed to migrate database: %v", err)
	}

	// 2. Initialize Embeddings
	modelPath := os.Getenv("GTE_MODEL_PATH")
	if modelPath == "" {
		modelPath = "models/gte-small.gtemodel"
	}

	embService, err := embeddings.NewService(modelPath)
	if err != nil {
		log.Fatalf("Failed to initialize embeddings service (is the model downloaded?): %v", err)
	}
	defer embService.Close()

	// 3. Setup Echo
	e := echo.New()
	
	// Middleware
	e.Use(middleware.Recover())
	e.Use(middleware.CORS("*")) // Allowed everywhere

	// 4. Register API Routes
	apiHandler := api.NewHandler(dbConn, embService)
	apiHandler.RegisterRoutes(e)

	// 5. Register Admin Routes
	adminHandler := admin.NewHandler(dbConn)
	adminHandler.RegisterRoutes(e)

	// 6. Start server
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Listening on port %s", port)
	if err := e.Start(":" + port); err != nil && err != http.ErrServerClosed {
		log.Fatalf("Shutting down the server: %v", err)
	}
}
