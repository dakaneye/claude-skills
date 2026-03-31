# Go Performance & Inefficiency Patterns

> Common performance anti-patterns. Load when reviewing performance-sensitive code.

## Activation Triggers

Load this document when:
- Reviewing hot paths or performance-critical code
- Code processes large slices or maps in loops
- Reviewing string manipulation in loops
- Profiling indicates performance issues

## O(n²) Loop Anti-Patterns

```go
// AI SMELL: Slice search inside loop = O(n²)
for _, order := range orders {
    var customer *Customer
    for _, c := range customers {
        if c.ID == order.CustomerID {
            customer = c
            break
        }
    }
    processOrder(order, customer)
}

// RIGHT: Build map first = O(n)
customerMap := make(map[string]*Customer, len(customers))
for _, c := range customers {
    customerMap[c.ID] = c
}
for _, order := range orders {
    customer := customerMap[order.CustomerID]
    processOrder(order, customer)
}
```

## Slice Append Without Pre-allocation

```go
// AI SMELL: Append grows slice repeatedly
var result []Item
for _, raw := range rawItems {
    result = append(result, transform(raw))  // May reallocate
}

// RIGHT: Pre-allocate when size is known
result := make([]Item, 0, len(rawItems))
for _, raw := range rawItems {
    result = append(result, transform(raw))  // No reallocation
}

// EVEN BETTER: Direct indexing when 1:1
result := make([]Item, len(rawItems))
for i, raw := range rawItems {
    result[i] = transform(raw)
}
```

## String Building in Loops

```go
// AI SMELL: String concatenation in loop
var result string
for _, item := range items {
    result += fmt.Sprintf("- %s\n", item.Name)  // New string each time
}

// RIGHT: strings.Builder
var sb strings.Builder
for _, item := range items {
    fmt.Fprintf(&sb, "- %s\n", item.Name)
}
result := sb.String()

// RIGHT: strings.Join for simple cases
lines := make([]string, len(items))
for i, item := range items {
    lines[i] = "- " + item.Name
}
result := strings.Join(lines, "\n")
```

## Repeated Regex Compilation

```go
// AI SMELL: Compiling regex on every call
func isValid(s string) bool {
    matched, _ := regexp.MatchString(`^[a-z0-9]+$`, s)  // Compiles each time
    return matched
}

// RIGHT: Compile once at package level
var validPattern = regexp.MustCompile(`^[a-z0-9]+$`)

func isValid(s string) bool {
    return validPattern.MatchString(s)
}
```

## Unnecessary Allocations

```go
// WRONG: Converting []byte to string just to compare
if string(data) == "expected" {
    // Allocates new string
}

// RIGHT: Compare bytes directly
if bytes.Equal(data, []byte("expected")) {
    // No allocation
}
```

## Map Without Size Hint

```go
// WRONG: Map grows repeatedly
m := make(map[string]int)  // No size hint
for _, item := range largeSlice {
    m[item.Key] = item.Value  // May rehash multiple times
}

// RIGHT: Size hint when you know approximate size
m := make(map[string]int, len(largeSlice))
for _, item := range largeSlice {
    m[item.Key] = item.Value  // Fewer rehashes
}
```

## Defer in Hot Loops

```go
// AI SMELL: Defer in tight loop accumulates
func processAll(files []string) error {
    for _, f := range files {
        file, err := os.Open(f)
        if err != nil {
            return err
        }
        defer file.Close()  // Defers pile up!
        process(file)
    }
    return nil
}

// RIGHT: Extract to function so defer runs each iteration
func processAll(files []string) error {
    for _, f := range files {
        if err := processFile(f); err != nil {
            return err
        }
    }
    return nil
}

func processFile(path string) error {
    file, err := os.Open(path)
    if err != nil {
        return err
    }
    defer file.Close()  // Runs when processFile returns
    return process(file)
}
```

## Sequential HTTP When Parallel Works

```go
// WRONG: Sequential requests
var results []Result
for _, url := range urls {
    resp, err := http.Get(url)
    if err != nil {
        return nil, err
    }
    results = append(results, parseResponse(resp))
}

// RIGHT: Parallel with errgroup
g, ctx := errgroup.WithContext(ctx)
results := make([]Result, len(urls))

for i, url := range urls {
    i, url := i, url  // Capture loop variables
    g.Go(func() error {
        req, _ := http.NewRequestWithContext(ctx, "GET", url, nil)
        resp, err := http.DefaultClient.Do(req)
        if err != nil {
            return err
        }
        results[i] = parseResponse(resp)
        return nil
    })
}

if err := g.Wait(); err != nil {
    return nil, err
}
```

## Review Checklist

- [ ] **[BLOCKER]** No O(n²) slice searches in hot paths (use map)
- [ ] **[BLOCKER]** No defer in hot loops
- [ ] **[MAJOR]** Regex compiled once at package level
- [ ] **[MAJOR]** String building uses strings.Builder in loops
- [ ] **[MINOR]** Slices pre-allocated when size known
- [ ] **[MINOR]** Maps have size hints when size is known
- [ ] **[MINOR]** Parallel I/O when requests are independent
- [ ] **[MINOR]** bytes.Equal instead of string conversion for comparison

## Related Documents

- `go-concurrency.md` - Parallel processing patterns
- `go-concurrency-patterns.md` - Worker pools, bounded concurrency
- `go-ai-antipatterns.md` - Premature optimization patterns
