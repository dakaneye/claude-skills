package api

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"time"
)

// ListHandler returns a paginated list of items.
type ListHandler struct {
	store Store
	log   *slog.Logger
}

// Store defines the data access interface.
type Store interface {
	List(ctx context.Context, cursor string, limit int) ([]Item, string, error)
}

// Item represents a list entry.
type Item struct {
	ID        string    `json:"id"`
	Name      string    `json:"name"`
	CreatedAt time.Time `json:"created_at"`
}

// NewListHandler creates a handler with the given store and logger.
func NewListHandler(store Store, log *slog.Logger) *ListHandler {
	return &ListHandler{store: store, log: log}
}

// ServeHTTP handles GET /items?cursor=X&limit=N
func (h *ListHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	cursor := r.URL.Query().Get("cursor")
	limit := 20 // sensible default

	items, nextCursor, err := h.store.List(r.Context(), cursor, limit)
	if err != nil {
		h.log.ErrorContext(r.Context(), "list items failed", "error", err, "cursor", cursor)
		if errors.Is(err, context.Canceled) {
			return // client disconnected
		}
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(map[string]any{
		"items":       items,
		"next_cursor": nextCursor,
	}); err != nil {
		h.log.ErrorContext(r.Context(), "encode response failed", "error", err)
	}
}
