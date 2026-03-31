# Pattern Detection Signals

> Flat checklist of "flag this" signals for code review. Organized by severity.

## Blockers (Must Fix)

### Reliability
- [ ] God Object: class >500 LOC doing everything (split by responsibility)
- [ ] Retry on non-idempotent operations (data corruption risk)
- [ ] Remote calls without timeout (system hang risk)
- [ ] Observer/listener without cleanup (memory leak)

### Over-Engineering
- [ ] Factory/Strategy/Abstract Factory with single implementation (YAGNI)
- [ ] Interface with one concrete class (premature abstraction)
- [ ] Cargo-cult pattern usage ("best practice" without actual need)

### Architecture
- [ ] Distributed monolith: microservices that must deploy together
- [ ] Missing bounded context: shared models across service boundaries

## Major (Should Fix)

### Design Smells
- [ ] Anemic domain: entities with only getters/setters, logic in services
- [ ] Generic Repository<T> when only one entity type exists
- [ ] Builder pattern for objects with 2-3 fields (use constructor/record)
- [ ] Decorator chain deeper than 3 levels
- [ ] Service Layer that just delegates to repository (no logic)

### Performance
- [ ] O(n^2) lookups: list search inside loop (use Map/Set)
- [ ] Missing caching on repeated expensive operations (with evidence)
- [ ] Sequential I/O when parallel is safe
- [ ] Regex/JSON parsing inside loops (compile/parse once)

### Consistency
- [ ] Same pattern used differently in different places
- [ ] New abstraction when existing one covers the use case
- [ ] Mixed paradigms without justification (OOP + functional in same module)

## Minor (Consider)

- [ ] Pattern not named/documented for future readers
- [ ] Golden hammer: same pattern applied everywhere regardless of fit
- [ ] Lava flow: dead code nobody dares delete (remove with tests)

## Language-Specific Pattern Translations

| Pattern | Java | Go | Python | JavaScript |
|---------|------|----|--------|------------|
| Builder | Static inner class | Functional Options | `dataclass` + kwargs | Object spread `{...defaults}` |
| Strategy | `@FunctionalInterface` | Interface + func | `Callable` / Protocol | Functions/closures |
| Factory | Static factory methods | `NewX()` constructor | Factory function | `createX()` function |
| Singleton | DI container | `sync.Once` (prefer DI) | Module-level instance | Module exports |
| Observer | Listeners/Events | Channels | Callbacks / signals | EventEmitter |
| Repository | JPA interface + impl | Interface + struct | ABC + SQLAlchemy | Class with DB client |

## Quick Decision: Is This Pattern Justified?

1. Does it solve a **current** problem? (not "might need later")
2. Is there a **simpler** alternative? (3 lines of code > 1 abstraction)
3. Does the codebase already have a pattern for this? (use it)
4. Will a new developer understand why this pattern is here?

If any answer is "no", the pattern is likely premature.

## Deep Dives

Individual pattern files in subdirectories:
- `gof/` - Gang of Four (creational, structural, behavioral)
- `enterprise/` - Repository, Unit of Work, Service Layer
- `architecture/` - 12-Factor, Clean Architecture, CQRS
- `ddd/` - Aggregates, Bounded Contexts, Domain Events
- `reliability/` - Circuit Breaker, Retry, Bulkhead, Timeout
- `distributed/` - Consistency, Replication, Idempotency
- `anti-patterns/` - God Object, Anemic Domain, Premature Abstraction
