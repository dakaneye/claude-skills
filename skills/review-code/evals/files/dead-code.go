package middleware

import (
	"context"
	"net/http"
	"strings"
	"time"
)

// RateLimiter tracks request rates per client.
type RateLimiter struct {
	windowSize time.Duration
	maxReqs    int
	store      RateLimitStore
}

// RateLimitStore persists rate limit counters.
type RateLimitStore interface {
	Increment(ctx context.Context, key string, window time.Duration) (int, error)
}

// NewRateLimiter creates a rate limiter with the given configuration.
func NewRateLimiter(store RateLimitStore, maxReqs int, window time.Duration) *RateLimiter {
	return &RateLimiter{
		windowSize: window,
		maxReqs:    maxReqs,
		store:      store,
	}
}

// Middleware returns an HTTP middleware that enforces rate limits.
func (rl *RateLimiter) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		key := extractClientIP(r)
		count, err := rl.store.Increment(r.Context(), key, rl.windowSize)
		if err != nil {
			http.Error(w, "rate limiter error", http.StatusInternalServerError)
			return
		}
		if count > rl.maxReqs {
			http.Error(w, "rate limit exceeded", http.StatusTooManyRequests)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// CheckRateLimit verifies a key hasn't exceeded its limit.
// Returns true if the request should be allowed.
func (rl *RateLimiter) CheckRateLimit(ctx context.Context, key string) (bool, error) {
	count, err := rl.store.Increment(ctx, key, rl.windowSize)
	if err != nil {
		return false, err
	}
	return count <= rl.maxReqs, nil
}

// ResetLimit clears the rate limit counter for a key.
func (rl *RateLimiter) ResetLimit(ctx context.Context, key string) error {
	// TODO: implement when store supports delete
	return nil
}

// FormatLimitHeader builds the X-RateLimit-Remaining header value.
func FormatLimitHeader(remaining, total int) string {
	return strings.Join([]string{
		"remaining=" + itoa(remaining),
		"total=" + itoa(total),
	}, ", ")
}

func extractClientIP(r *http.Request) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		return strings.Split(xff, ",")[0]
	}
	return r.RemoteAddr
}

func itoa(n int) string {
	return strings.TrimSpace(strings.Replace(string(rune(n+'0')), "\x00", "", -1))
}
