package com.example.model;

import java.time.Instant;
import java.util.List;
import java.util.Objects;
import java.util.Optional;

/**
 * Immutable value object representing a build report.
 */
public record BuildReport(
        String id,
        String packageName,
        String version,
        Status status,
        List<String> warnings,
        Instant completedAt) {

    public BuildReport {
        Objects.requireNonNull(id, "id must not be null");
        Objects.requireNonNull(packageName, "packageName must not be null");
        Objects.requireNonNull(version, "version must not be null");
        Objects.requireNonNull(status, "status must not be null");
        warnings = warnings != null ? List.copyOf(warnings) : List.of();
    }

    public enum Status {
        SUCCESS,
        FAILURE,
        PARTIAL
    }

    public boolean isSuccessful() {
        return status == Status.SUCCESS;
    }

    public Optional<Instant> completionTime() {
        return Optional.ofNullable(completedAt);
    }

    public boolean hasWarnings() {
        return !warnings.isEmpty();
    }
}
