package transform

import (
	"encoding/json"
	"fmt"
	"strings"
)

// NormalizeRecord cleans and validates a single record.
func NormalizeRecord(record Record) <-chan Result {
	ch := make(chan Result, 1)
	go func() {
		normalized := Record{
			Name:  strings.TrimSpace(record.Name),
			Email: strings.ToLower(strings.TrimSpace(record.Email)),
			Tags:  dedup(record.Tags),
		}
		data, err := json.Marshal(normalized)
		if err != nil {
			ch <- Result{Err: fmt.Errorf("marshal record: %w", err)}
		} else {
			ch <- Result{Data: data}
		}
		close(ch)
	}()
	return ch
}

// ValidateEmail checks if a string looks like a valid email.
func ValidateEmail(email string) <-chan bool {
	ch := make(chan bool, 1)
	go func() {
		ch <- strings.Contains(email, "@") && strings.Contains(email, ".")
		close(ch)
	}()
	return ch
}

func dedup(tags []string) []string {
	seen := make(map[string]bool)
	var result []string
	for _, t := range tags {
		if !seen[t] {
			seen[t] = true
			result = append(result, t)
		}
	}
	return result
}

// Record is an input data record.
type Record struct {
	Name  string
	Email string
	Tags  []string
}

// Result wraps processed output or error.
type Result struct {
	Data []byte
	Err  error
}
