package users

import (
	"context"
	"database/sql"
	"fmt"
)

// User represents a user record. The 'role' column was added in migration 042.
type User struct {
	ID    string
	Email string
	Name  string
	Role  string
}

// GetActiveAdmins returns all users with role='admin' and an active status.
func GetActiveAdmins(ctx context.Context, db *sql.DB) ([]User, error) {
	rows, err := db.QueryContext(ctx,
		"SELECT id, email, name, role FROM users WHERE role = 'admin' AND status = 'active'")
	if err != nil {
		return nil, fmt.Errorf("query active admins: %w", err)
	}
	defer rows.Close()

	var users []User
	for rows.Next() {
		var u User
		if err := rows.Scan(&u.ID, &u.Email, &u.Name, &u.Role); err != nil {
			return nil, fmt.Errorf("scan user: %w", err)
		}
		users = append(users, u)
	}
	return users, rows.Err()
}

// CountByRole returns the number of users per role using a GROUP BY.
func CountByRole(ctx context.Context, db *sql.DB) (map[string]int, error) {
	rows, err := db.QueryContext(ctx,
		"SELECT role, COUNT(*) FROM users GROUP BY role")
	if err != nil {
		return nil, fmt.Errorf("count by role: %w", err)
	}
	defer rows.Close()

	counts := make(map[string]int)
	for rows.Next() {
		var role string
		var count int
		if err := rows.Scan(&role, &count); err != nil {
			return nil, fmt.Errorf("scan count: %w", err)
		}
		counts[role] = count
	}
	return counts, rows.Err()
}
