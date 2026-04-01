# Rust Iterators & Functional Patterns

> Zero-cost iterator abstractions and idiomatic data transformation. Load when reviewing iteration-heavy code.

## Activation Triggers

Load this document when:
- Code uses `.iter()`, `.into_iter()`, or `.iter_mut()`
- File contains `.map()`, `.filter()`, `.collect()`, `.fold()`, `.chain()`
- C-style `for i in 0..vec.len()` with index access appears
- Complex data transformation pipelines need review

## iter vs into_iter vs iter_mut

Three ways to iterate, each with different ownership semantics:

| Method | Yields | Ownership | Use When |
|--------|--------|-----------|----------|
| `.iter()` | `&T` | Borrows | Read-only traversal |
| `.into_iter()` | `T` | Consumes | Done with the collection |
| `.iter_mut()` | `&mut T` | Mutably borrows | Modifying elements in place |

```rust
let names = vec!["alpha".to_string(), "beta".to_string()];

// BAD: consumes the vec, can't use `names` afterward
let upper: Vec<String> = names.into_iter().map(|n| n.to_uppercase()).collect();
// println!("{:?}", names);  // ERROR: value moved

// GOOD: borrows, `names` remains usable
let names = vec!["alpha".to_string(), "beta".to_string()];
let upper: Vec<String> = names.iter().map(|n| n.to_uppercase()).collect();
println!("{:?}", names);  // Fine — still owned

// GOOD: mutate in place when that's the intent
let mut scores = vec![80, 90, 70];
scores.iter_mut().for_each(|s| *s += 10);
```

**Rule of thumb**: Start with `.iter()`. Only reach for `.into_iter()` when the collection is no longer needed.

## C-Style Loops vs Iterator Chains

```rust
let items = vec![10, 20, 30, 40, 50];

// BAD: index-based access — bounds checked on every access, not idiomatic
let mut result = Vec::new();
for i in 0..items.len() {
    if items[i] > 20 {
        result.push(items[i] * 2);
    }
}

// GOOD: iterator chain — zero-cost abstraction, no bounds checks
let result: Vec<i32> = items.iter()
    .filter(|&&x| x > 20)
    .map(|&x| x * 2)
    .collect();
```

**Why**: Iterators are zero-cost abstractions. The compiler optimizes chains to the same machine code as hand-written loops, often with better vectorization because it can prove the absence of aliasing.

## Common Combinators

The most important iterator methods at a glance:

```rust
// map — transform each element
[1, 2, 3].iter().map(|x| x * 2)                    // [2, 4, 6]

// filter — keep elements matching a predicate
[1, 2, 3, 4].iter().filter(|&&x| x % 2 == 0)       // [2, 4]

// filter_map — filter and transform in one step (eliminates Option::None)
["1", "bad", "3"].iter().filter_map(|s| s.parse::<i32>().ok())  // [1, 3]

// flat_map — map then flatten nested iterators
vec![vec![1, 2], vec![3]].iter().flat_map(|v| v.iter())  // [1, 2, 3]

// chain — concatenate two iterators
[1, 2].iter().chain([3, 4].iter())                   // [1, 2, 3, 4]

// zip — pair elements from two iterators
["a", "b"].iter().zip([1, 2].iter())                 // [("a", 1), ("b", 2)]

// enumerate — attach index to each element
["x", "y"].iter().enumerate()                        // [(0, "x"), (1, "y")]

// take / skip — limit or offset
(0..100).take(3)                                     // [0, 1, 2]
(0..100).skip(97)                                    // [97, 98, 99]

// any / all — short-circuit boolean checks
[1, 2, 3].iter().any(|&x| x > 2)                    // true
[1, 2, 3].iter().all(|&x| x > 0)                    // true

// find — first element matching predicate
[1, 2, 3].iter().find(|&&x| x > 1)                  // Some(&2)

// sum / product — numeric reduction
[1, 2, 3].iter().sum::<i32>()                        // 6

// min_by / max_by — comparison-based extremes
items.iter().max_by(|a, b| a.score.cmp(&b.score))

// partition — split into two collections by predicate
let (evens, odds): (Vec<_>, Vec<_>) = (0..10).partition(|x| x % 2 == 0);

// unzip — split pairs into two collections
let (keys, vals): (Vec<_>, Vec<_>) = pairs.into_iter().unzip();
```

## collect() and Type Annotations

`.collect()` is polymorphic — the return type determines what gets built:

```rust
let nums = vec![1, 2, 3, 4, 5];

// Collect into Vec (turbofish syntax)
let doubled = nums.iter().map(|x| x * 2).collect::<Vec<_>>();

// Collect into HashMap
use std::collections::HashMap;
let map: HashMap<&str, i32> = vec![("a", 1), ("b", 2)].into_iter().collect();

// Collect into String
let csv: String = ["one", "two", "three"].iter().copied().collect::<Vec<_>>().join(",");
// Or: chars into String
let s: String = ['h', 'i'].iter().collect();

// Collect Result<Vec<T>, E> — short-circuits on first error
let parsed: Result<Vec<i32>, _> = ["1", "2", "bad"]
    .iter()
    .map(|s| s.parse::<i32>())
    .collect();  // Err(ParseIntError)
```

**When turbofish is needed**: When the compiler can't infer the target type from context. A type annotation on the binding (`let x: Vec<_> = ...`) works too.

## Iterator Chains for Data Transformation

```rust
use std::collections::HashMap;

struct Pod {
    name: String,
    namespace: String,
    labels: HashMap<String, String>,
    ready: bool,
}

// BAD: imperative accumulation
let mut unhealthy = Vec::new();
for pod in &pods {
    if pod.namespace == "production" {
        if !pod.ready {
            if pod.labels.get("app").is_some() {
                unhealthy.push(format!("{}/{}", pod.namespace, pod.name));
            }
        }
    }
}

// GOOD: declarative pipeline — intent reads top to bottom
let unhealthy: Vec<String> = pods.iter()
    .filter(|p| p.namespace == "production")
    .filter(|p| !p.ready)
    .filter(|p| p.labels.contains_key("app"))
    .map(|p| format!("{}/{}", p.namespace, p.name))
    .collect();
```

## Lazy Evaluation

Iterators are lazy. Nothing executes until a terminal operation consumes the chain:

```rust
let v = vec![1, 2, 3, 4, 5];

// This does NOTHING — no terminal operation
v.iter().map(|x| {
    println!("processing {}", x);  // Never prints
    x * 2
});

// Terminal operations that drive evaluation:
// .collect(), .for_each(), .sum(), .count(), .any(), .all(), .find(), .last()

// GOOD: lazy means no intermediate allocations
// This creates ONE iterator pipeline, not three intermediate Vecs
let result: Vec<i32> = (0..1_000_000)
    .filter(|x| x % 3 == 0)
    .map(|x| x * 2)
    .take(10)
    .collect();  // Only processes elements until 10 are found
```

**Key insight**: Chaining `.filter().map().take()` does not allocate three vectors. Each element flows through the entire pipeline before the next is pulled. This is fundamentally different from eager languages where each step materializes a new collection.

## When Imperative Loops Are Fine

Don't force everything into a chain. A `for` loop is clearer when:

```rust
// Complex state machines — loop is clearer
let mut state = State::Start;
for event in events {
    state = match (state, event) {
        (State::Start, Event::Init) => State::Running,
        (State::Running, Event::Error(e)) => {
            log::error!("failure: {e}");
            return Err(e);  // Early return with side effects
        }
        (s, _) => s,
    };
}

// Mutable borrows during iteration — can't easily express as chain
let mut items = vec![1, 2, 3];
let mut i = 0;
while i < items.len() {
    if items[i] % 2 == 0 {
        items.remove(i);  // Mutating the collection
    } else {
        i += 1;
    }
}

// Multiple collections updated in lockstep
for (src, dst) in sources.iter().zip(destinations.iter_mut()) {
    if src.is_valid() {
        dst.update_from(src);
        audit_log.push(src.id());  // Side effect on third collection
    }
}
```

**Guideline**: If the chain needs more than one `.inspect()` to debug, or requires `.fold()` with a complex accumulator struct, a `for` loop probably communicates intent better.

## Review Checklist

- [ ] **[MAJOR]** Iterator combinators over C-style index loops
- [ ] **[MAJOR]** `.iter()` for read-only, `.into_iter()` only when consuming
- [ ] **[MAJOR]** `.collect()` has clear target type (turbofish or binding annotation)
- [ ] **[MAJOR]** `filter_map` used instead of `.filter().map()` when extracting from `Option`
- [ ] **[MINOR]** Prefer built-in methods (`.sum()`, `.any()`, `.all()`) over manual accumulation
- [ ] **[MINOR]** Complex chains broken into readable intermediate bindings when needed

## Related Documents

- `rust-ownership.md` - Ownership semantics that govern iterator choice
