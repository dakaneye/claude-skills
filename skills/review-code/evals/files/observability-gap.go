package webhook

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
)

// Handler processes incoming webhook events from payment provider.
type Handler struct {
	store EventStore
}

// EventStore persists webhook events.
type EventStore interface {
	Save(ctx context.Context, event Event) error
}

// Event represents a parsed webhook payload.
type Event struct {
	ID     string `json:"id"`
	Type   string `json:"type"`
	Amount int64  `json:"amount"`
}

// ServeHTTP handles POST /webhooks/payments
func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	var event Event
	if err := json.NewDecoder(r.Body).Decode(&event); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		return
	}

	if err := h.store.Save(r.Context(), event); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, `{"status":"ok"}`)
}
