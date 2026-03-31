# The Twelve-Factor App

> Methodology for building software-as-a-service apps that are portable, scalable, and maintainable. Essential for cloud-native and containerized applications.

**Source**: https://12factor.net (Heroku, 2011)

## Overview

The twelve factors are patterns for apps that:
- Use declarative formats for setup automation
- Have a clean contract with the underlying OS
- Are suitable for deployment on modern cloud platforms
- Minimize divergence between development and production
- Can scale up without significant changes

## The Twelve Factors

### I. Codebase
**One codebase tracked in revision control, many deploys**

```
✅ GOOD                          ❌ BAD

┌─────────────┐                  ┌─────────────┐  ┌─────────────┐
│  Git Repo   │                  │  Repo A     │  │  Repo B     │
│  (single)   │                  │  (prod)     │  │  (staging)  │
└──────┬──────┘                  └─────────────┘  └─────────────┘
       │                         Different codebases for same app
  ┌────┴────┐
  │         │
prod     staging
(same code, different config)
```

**Review Checklist:**
- [ ] **[BLOCKER]** Single repo for the app (monorepo OK, multi-app repos bad)
- [ ] **[MAJOR]** All environments use same codebase
- [ ] **[MAJOR]** No environment-specific branches (use config instead)

### II. Dependencies
**Explicitly declare and isolate dependencies**

```bash
# GOOD: Explicit declaration
# Java
<dependency>
    <groupId>com.example</groupId>
    <artifactId>library</artifactId>
    <version>1.2.3</version>  <!-- Pinned version -->
</dependency>

# Go
require github.com/example/lib v1.2.3

# Python
requirements.txt or pyproject.toml with pinned versions

# Node
package-lock.json committed
```

**Review Checklist:**
- [ ] **[BLOCKER]** No system-wide packages assumed (curl, imagemagick, etc.)
- [ ] **[BLOCKER]** Lock file committed (go.sum, package-lock.json, etc.)
- [ ] **[MAJOR]** Versions pinned, not floating (^1.0.0 → 1.2.3)
- [ ] **[MINOR]** Vendor directory if hermetic builds required

### III. Config
**Store config in the environment**

```java
// BAD: Hardcoded config
private static final String DB_URL = "jdbc:postgresql://prod-db:5432/app";

// BAD: Config file with secrets
config.properties:
  db.password=hunter2

// GOOD: Environment variables
String dbUrl = System.getenv("DATABASE_URL");
String dbPassword = System.getenv("DB_PASSWORD");

// GOOD: With validation
String dbUrl = Optional.ofNullable(System.getenv("DATABASE_URL"))
    .orElseThrow(() -> new IllegalStateException("DATABASE_URL required"));
```

**What IS Config:**
- Database credentials and URLs
- API keys for external services
- Feature flags
- Per-deploy values (hostnames, ports)

**What is NOT Config:**
- Code paths, routing rules (that's code)
- Constants that don't change between deploys

**Review Checklist:**
- [ ] **[BLOCKER]** No secrets in code or committed config files
- [ ] **[BLOCKER]** No environment-specific code paths (`if (env == "prod")`)
- [ ] **[MAJOR]** Config read from environment variables
- [ ] **[MAJOR]** Required config validated at startup

### IV. Backing Services
**Treat backing services as attached resources**

```
┌─────────────┐
│    App      │
└──────┬──────┘
       │ URLs/credentials from env
       │
┌──────┴─────────────────────────────────┐
│                                        │
▼           ▼              ▼             ▼
PostgreSQL  Redis         S3           Stripe
(local)     (managed)     (AWS)        (SaaS)

All treated the same - swappable via config
```

**Review Checklist:**
- [ ] **[BLOCKER]** No hardcoded service URLs
- [ ] **[MAJOR]** Services accessed via injected configuration
- [ ] **[MAJOR]** Can swap local DB for managed DB via config only
- [ ] **[MINOR]** Connection pooling configured appropriately

### V. Build, Release, Run
**Strictly separate build and run stages**

```
┌─────────┐    ┌─────────┐    ┌─────────┐
│  Build  │───▶│ Release │───▶│   Run   │
└─────────┘    └─────────┘    └─────────┘
    │              │              │
    │              │              │
  code +        build +        release
  deps =        config =       started
  build         release

Each release has unique ID (v1.2.3, commit SHA)
```

**Review Checklist:**
- [ ] **[BLOCKER]** No runtime compilation or code modification
- [ ] **[MAJOR]** Build produces immutable artifact (container image, JAR)
- [ ] **[MAJOR]** Config injected at release/run time, not build time
- [ ] **[MINOR]** Releases are immutable and versioned

### VI. Processes
**Execute the app as one or more stateless processes**

```java
// BAD: In-memory session state
private Map<String, Session> sessions = new HashMap<>();

public void handleRequest(Request req) {
    Session session = sessions.get(req.getSessionId());  // Lost on restart!
}

// GOOD: External session store
public void handleRequest(Request req) {
    Session session = redis.get("session:" + req.getSessionId());
}
```

**Review Checklist:**
- [ ] **[BLOCKER]** No local filesystem for persistent data
- [ ] **[BLOCKER]** No in-memory state shared between requests
- [ ] **[MAJOR]** Session data in external store (Redis, database)
- [ ] **[MAJOR]** Sticky sessions not required

### VII. Port Binding
**Export services via port binding**

```go
// GOOD: Self-contained HTTP server
func main() {
    port := os.Getenv("PORT")
    if port == "" {
        port = "8080"
    }
    http.ListenAndServe(":"+port, handler)
}
```

**Review Checklist:**
- [ ] **[MAJOR]** App is self-contained (not deployed into app server)
- [ ] **[MAJOR]** Port configurable via environment
- [ ] **[MINOR]** Health check endpoint available

### VIII. Concurrency
**Scale out via the process model**

```
┌────────────────────────────────────┐
│              Dyno/Pod              │
│  ┌─────────────────────────────┐   │
│  │  Process 1   Process 2      │   │
│  │    (web)       (worker)     │   │
│  └─────────────────────────────┘   │
└────────────────────────────────────┘
              ×3 (horizontal scale)
```

**Review Checklist:**
- [ ] **[MAJOR]** App can run multiple instances concurrently
- [ ] **[MAJOR]** No reliance on specific instance (affinity)
- [ ] **[MAJOR]** Work can be distributed across processes/pods

### IX. Disposability
**Maximize robustness with fast startup and graceful shutdown**

```go
// GOOD: Graceful shutdown
func main() {
    srv := &http.Server{Addr: ":8080", Handler: handler}

    go srv.ListenAndServe()

    // Wait for interrupt
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    // Graceful shutdown with timeout
    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()

    if err := srv.Shutdown(ctx); err != nil {
        log.Fatal("Server forced to shutdown:", err)
    }
}
```

**Review Checklist:**
- [ ] **[BLOCKER]** Handles SIGTERM gracefully (finish in-flight requests)
- [ ] **[MAJOR]** Startup time < 10 seconds
- [ ] **[MAJOR]** Crash-only design (can be killed and restarted anytime)
- [ ] **[MINOR]** Connections closed properly on shutdown

### X. Dev/Prod Parity
**Keep development, staging, and production as similar as possible**

| Gap | Traditional | Twelve-Factor |
|-----|-------------|---------------|
| Time | Weeks between deploys | Hours |
| Personnel | Devs write, ops deploy | Devs deploy |
| Tools | SQLite/H2 dev, Postgres prod | Same everywhere |

**Review Checklist:**
- [ ] **[BLOCKER]** Same database type in dev and prod
- [ ] **[MAJOR]** Same backing services in dev (containers help)
- [ ] **[MAJOR]** No "works on my machine" dependencies
- [ ] **[MINOR]** docker-compose or similar for local dev

### XI. Logs
**Treat logs as event streams**

```java
// BAD: Managing log files
FileWriter fw = new FileWriter("/var/log/app.log");
fw.write(logMessage);

// GOOD: Write to stdout, let platform route
System.out.println(logMessage);
// Or structured logging to stdout
logger.info("Request processed",
    Map.of("requestId", requestId, "duration", duration));
```

**Review Checklist:**
- [ ] **[BLOCKER]** Logs written to stdout/stderr, not files
- [ ] **[MAJOR]** No log rotation in app (platform handles it)
- [ ] **[MAJOR]** Structured logging (JSON) for machine parsing
- [ ] **[MINOR]** Request IDs for tracing

### XII. Admin Processes
**Run admin/management tasks as one-off processes**

```bash
# GOOD: One-off process with same codebase
kubectl exec -it deployment/app -- python manage.py migrate

# GOOD: Job that runs same image
apiVersion: batch/v1
kind: Job
spec:
  template:
    spec:
      containers:
      - name: migrate
        image: myapp:v1.2.3  # Same image as app
        command: ["python", "manage.py", "migrate"]
```

**Review Checklist:**
- [ ] **[MAJOR]** Admin tasks use same codebase/image
- [ ] **[MAJOR]** Migrations run as one-off process
- [ ] **[MINOR]** REPL available for debugging

## Combined Review Checklist

### Configuration & Secrets
- [ ] **[BLOCKER]** No secrets in code or committed files
- [ ] **[BLOCKER]** Config from environment variables
- [ ] **[MAJOR]** Required config validated at startup

### Statelessness & Portability
- [ ] **[BLOCKER]** No local filesystem persistence
- [ ] **[BLOCKER]** No in-memory state between requests
- [ ] **[MAJOR]** Backing services swappable via config

### Operations
- [ ] **[BLOCKER]** Graceful shutdown on SIGTERM
- [ ] **[BLOCKER]** Logs to stdout/stderr
- [ ] **[MAJOR]** Health check endpoint
- [ ] **[MAJOR]** Fast startup (<10s)

### Dependencies
- [ ] **[BLOCKER]** Lock file committed
- [ ] **[MAJOR]** No system dependencies assumed
- [ ] **[MAJOR]** Same services in dev and prod

## Anti-Patterns to Flag

```java
// ANTI-PATTERN: Environment-specific code
if (System.getenv("ENV").equals("production")) {
    enableFeatureX();  // Should be config, not code
}

// ANTI-PATTERN: Local file state
File cache = new File("/tmp/cache.json");
cache.write(data);  // Lost on restart, not shared across instances

// ANTI-PATTERN: Hardcoded service URL
HttpClient client = HttpClient.create("http://api.internal:8080");
// Should be: HttpClient.create(System.getenv("API_URL"))

// ANTI-PATTERN: Log to file
Logger.addHandler(new FileHandler("/var/log/app.log"));
// Should log to stdout
```

## Popular Libraries

| Language | Library | Notes |
|----------|---------|-------|
| **Java** | [Spring Boot](https://spring.io/projects/spring-boot) | Env-based config, embedded server, health endpoints |
| **Java** | [Micronaut](https://micronaut.io/) | Cloud-native features with fast startup |
| **Java** | [Logback](https://logback.qos.ch/) | Console appender for stdout logging |
| **Go** | [Viper](https://github.com/spf13/viper) | Config from env vars, files, remote sources |
| **Go** | [envconfig](https://github.com/kelseyhightower/envconfig) | Struct-based environment variable parsing |
| **Go** | [slog](https://pkg.go.dev/log/slog) | Structured logging to stdout (stdlib) |
| **Python** | [python-dotenv](https://pypi.org/project/python-dotenv/) | Load env vars from .env files |
| **Python** | [pydantic-settings](https://docs.pydantic.dev/latest/concepts/pydantic_settings/) | Typed config from environment |
| **Python** | [structlog](https://www.structlog.org/) | Structured logging for stdout output |
| **JavaScript** | [dotenv](https://github.com/motdotla/dotenv) | Load env vars from .env files |
| **JavaScript** | [config](https://github.com/node-config/node-config) | Environment-based configuration |
| **JavaScript** | [pino](https://getpino.io/) | Fast JSON logging to stdout |
| **Multi** | [Docker](https://www.docker.com/) | Containerization for build/release/run separation |
| **Multi** | [Kubernetes](https://kubernetes.io/) | Orchestration supporting all 12 factors |
| **Multi** | [Helm](https://helm.sh/) | Package manager for K8s config injection |

**Note**: The Twelve-Factor methodology is about application design principles, not specific libraries. These tools help implement the factors (environment config, structured logging, health checks) but the patterns themselves are achieved through architecture decisions.

## References

- https://12factor.net (original manifesto)
- "Beyond the Twelve-Factor App" (Kevin Hoffman, O'Reilly)
- Kubernetes documentation on cloud-native patterns
