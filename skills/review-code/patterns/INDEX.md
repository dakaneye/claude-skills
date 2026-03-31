# Design Patterns Catalog

> For review signals and severity checklist, see `detection-signals.md`.
> For full pattern details, load specific files from subdirectories below.

## Subdirectories

| Directory | Contents |
|-----------|----------|
| `gof/creational/` | Factory Method, Abstract Factory, Builder, Singleton |
| `gof/structural/` | Adapter, Decorator, Facade, Proxy |
| `gof/behavioral/` | Strategy, Observer, Command, State, Template Method |
| `enterprise/` | Repository, Unit of Work, Data Mapper, Service Layer |
| `architecture/` | 12-Factor, Clean Architecture, Hexagonal, CQRS, Event Sourcing |
| `ddd/` | Aggregates, Bounded Contexts, Entities, Value Objects, Domain Events |
| `reliability/` | Circuit Breaker, Bulkhead, Timeout, Retry, Graceful Degradation |
| `distributed/` | Idempotency, Consistency Models, Replication, Partitioning |
| `anti-patterns/` | God Object, Anemic Domain, Distributed Monolith, Premature Abstraction |

## Quick Decision Matrix

| If you need to... | Consider |
|----|-----|
| Create complex objects | Builder, Factory Method |
| Add behavior dynamically | Decorator, Strategy |
| Decouple components | Observer, Mediator |
| Persist domain objects | Repository, Unit of Work |
| Handle remote failures | Circuit Breaker + Timeout + Retry |
| **Avoid** | God Object, Anemic Domain, Premature Abstraction |

## References

- **GoF**: Gamma et al., "Design Patterns" (1994)
- **PoEAA**: Fowler, "Patterns of Enterprise Application Architecture" (2002)
- **DDD**: Evans, "Domain-Driven Design" (2003)
- **Release It!**: Nygard, "Release It!" (2018)
- **DDIA**: Kleppmann, "Designing Data-Intensive Applications" (2017)
