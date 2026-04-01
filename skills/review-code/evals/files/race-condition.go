package wallet

import (
	"context"
	"database/sql"
	"fmt"
)

// Transfer moves funds between two accounts.
func Transfer(ctx context.Context, db *sql.DB, from, to string, amount int64) error {
	// Read sender balance
	var balance int64
	err := db.QueryRowContext(ctx, "SELECT balance FROM accounts WHERE id = $1", from).Scan(&balance)
	if err != nil {
		return fmt.Errorf("read sender balance: %w", err)
	}

	if balance < amount {
		return fmt.Errorf("insufficient funds: have %d, need %d", balance, amount)
	}

	// Deduct from sender
	_, err = db.ExecContext(ctx, "UPDATE accounts SET balance = balance - $1 WHERE id = $2", amount, from)
	if err != nil {
		return fmt.Errorf("deduct from sender: %w", err)
	}

	// Credit receiver
	_, err = db.ExecContext(ctx, "UPDATE accounts SET balance = balance + $1 WHERE id = $2", amount, to)
	if err != nil {
		return fmt.Errorf("credit receiver: %w", err)
	}

	return nil
}
