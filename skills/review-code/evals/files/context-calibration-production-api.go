package api

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"
)

// ServeUserAvatar handles GET /users/:id/avatar for the public-facing API.
// This endpoint serves ~2M requests/day.
func ServeUserAvatar(w http.ResponseWriter, r *http.Request) {
	userID := r.PathValue("id")

	avatarPath := filepath.Join("/data/avatars", userID+".png")

	data, err := os.ReadFile(avatarPath)
	if err != nil {
		w.WriteHeader(http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "image/png")
	w.Write(data)
}

// UploadAvatar handles POST /users/:id/avatar for the public-facing API.
func UploadAvatar(w http.ResponseWriter, r *http.Request) {
	userID := r.PathValue("id")

	if r.ContentLength > 5*1024*1024 {
		http.Error(w, "file too large", http.StatusRequestEntityTooLarge)
		return
	}

	outPath := filepath.Join("/data/avatars", userID+".png")
	out, err := os.Create(outPath)
	if err != nil {
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	defer out.Close()

	if _, err := out.ReadFrom(r.Body); err != nil {
		http.Error(w, "upload failed", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
	fmt.Fprintf(w, `{"status":"ok"}`)
}
