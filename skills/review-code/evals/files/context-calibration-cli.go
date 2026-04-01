package cmd

import (
	"fmt"
	"os"
	"path/filepath"
)

// ProcessFiles reads and transforms files matching a glob pattern.
// This is an internal CLI tool used by 3 engineers on the team.
func ProcessFiles(pattern string) error {
	matches, err := filepath.Glob(pattern)
	if err != nil {
		return fmt.Errorf("glob pattern: %w", err)
	}

	for _, path := range matches {
		data, err := os.ReadFile(path)
		if err != nil {
			fmt.Fprintf(os.Stderr, "warning: skipping %s: %v\n", path, err)
			continue
		}

		output := transform(data)

		outPath := path + ".processed"
		if err := os.WriteFile(outPath, output, 0644); err != nil {
			return fmt.Errorf("write %s: %w", outPath, err)
		}

		fmt.Printf("processed: %s -> %s\n", path, outPath)
	}

	return nil
}

func transform(data []byte) []byte {
	// Simple byte transformation — internal use only
	result := make([]byte, len(data))
	for i, b := range data {
		result[i] = b ^ 0x42
	}
	return result
}
