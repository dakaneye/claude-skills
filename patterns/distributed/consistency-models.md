# Consistency Models

> Rules that define the order and visibility of updates across distributed system components.

**Source**: Various; see "Designing Data-Intensive Applications" by Martin Kleppmann

## Intent

Understand and choose appropriate consistency guarantees for distributed systems. Different use cases require different trade-offs between consistency, availability, and latency.

## The CAP Theorem Context

In the presence of network **P**artitions, choose between:
- **C**onsistency: All nodes see the same data
- **A**vailability: All requests receive a response

```
        Consistency
           /\
          /  \
         /    \
        / CAP  \
       /________\
Availability    Partition Tolerance

You can only have 2 of 3, and P is non-negotiable in distributed systems.
So really it's: C or A during partitions.
```

## Consistency Spectrum

```
←─────────────────── Weaker ─────────────── Stronger ──────────────────→

Eventual     Read-Your-   Monotonic    Causal      Sequential   Linearizable
             Writes       Reads        Consistency  Consistency  (Strong)

Fast/Available ←─────────────────────────────────────────→ Slow/Correct
```

## Consistency Models Explained

### 1. Eventual Consistency
Updates propagate eventually; temporary inconsistencies allowed.

```
Time →
Node A: [X=1] ───────────────────────────► [X=2]
                    Write X=2
Node B: [X=1] ─────────────────► [X=2] ───► [X=2]
                          Eventually consistent
Node C: [X=1] ───────────────────────► [X=2] ► [X=2]
```

**Use when**: High availability more important than immediate consistency
**Examples**: Social media likes, view counts, DNS

### 2. Read-Your-Writes
After writing, you always see your own writes.

```
Client writes X=2 to Node A
Client reads from Node B

Without Read-Your-Writes:
Write(X=2) → Node A
Read(X) → Node B → returns X=1  ✗ (Stale!)

With Read-Your-Writes:
Write(X=2) → Node A
Read(X) → Node B → returns X=2  ✓ (Sees own write)
```

**Use when**: Users editing their own data
**Examples**: Profile updates, document editing

### 3. Monotonic Reads
Once you see a value, you never see an older value.

```
Client reads from different nodes

Without Monotonic Reads:
Read from A → X=2
Read from B → X=1  ✗ (Went backwards!)

With Monotonic Reads:
Read from A → X=2
Read from B → X=2 (or newer)  ✓
```

**Use when**: Reading data that should only move forward
**Examples**: Bank balance displays, notification counts

### 4. Causal Consistency
Operations that have a causal relationship are seen in order.

```
Alice posts: "I'm having a party!"
Bob replies: "I'll bring cake!"

Causal Order:
Observer 1: Alice's post → Bob's reply  ✓
Observer 2: Alice's post → Bob's reply  ✓

Without Causal Consistency:
Observer 3: Bob's reply → Alice's post  ✗ (Confusing!)
```

**Use when**: Related updates must be seen in order
**Examples**: Social media threads, document revisions

### 5. Sequential Consistency
All operations appear to execute in some total order.

```
Operations from all clients appear in single, agreed-upon order.

Client A: W(X=1) ────────────────────────►
Client B: ───────────► W(X=2) ───────────►

All observers see either:
  X=1 then X=2, OR
  X=2 then X=1
But ALL observers see the SAME order.
```

**Use when**: Global ordering matters, can tolerate some latency
**Examples**: Distributed locks, leader election

### 6. Linearizability (Strong Consistency)
Operations appear instantaneous and reflect real-time order.

```
Real time →
              Write X=2        Read X
Client A: ─────[────]──────────[──]───────►
                 │               │
                 ▼               ▼
              Must see:       Must return 2
              Happens now     (write completed before read started)
```

**Use when**: Absolute correctness required
**Examples**: Financial transactions, distributed locks, configuration

## Language Examples

### Java (Different Consistency Levels)

```java
// Eventual Consistency with Caching
@Service
public class ViewCountService {
    private final Cache<String, Long> localCache;
    private final ViewCountRepository repository;

    // Eventual consistency - fast reads from cache
    public long getViewCount(String articleId) {
        return localCache.get(articleId, () -> {
            return repository.getCount(articleId);
        });
    }

    // Async write - eventually consistent
    public void incrementViewCount(String articleId) {
        // Update local cache immediately
        localCache.merge(articleId, 1L, Long::sum);

        // Async persist - may be batched/delayed
        asyncExecutor.submit(() -> {
            repository.increment(articleId);
        });
    }
}

// Read-Your-Writes with Session Affinity
@Service
public class ProfileService {
    private final ProfileRepository repository;
    private final SessionStore sessionStore;

    public void updateProfile(String userId, ProfileUpdate update) {
        Profile profile = repository.update(userId, update);

        // Store version in session for read-your-writes
        sessionStore.setLastWriteVersion(userId, profile.getVersion());
    }

    public Profile getProfile(String userId, String sessionId) {
        Long lastWriteVersion = sessionStore.getLastWriteVersion(userId);

        // Ensure we read at least our last write
        return repository.findById(userId, lastWriteVersion);
    }
}

// Strong Consistency with Distributed Lock
@Service
public class AccountService {
    private final AccountRepository repository;
    private final DistributedLock lock;

    @Transactional
    public void transfer(String fromId, String toId, Money amount) {
        // Acquire locks in consistent order to prevent deadlock
        String[] orderedIds = Stream.of(fromId, toId).sorted().toArray(String[]::new);

        try {
            lock.acquire(orderedIds[0]);
            lock.acquire(orderedIds[1]);

            // Strong consistency - serialized access
            Account from = repository.findByIdForUpdate(fromId);
            Account to = repository.findByIdForUpdate(toId);

            from.debit(amount);
            to.credit(amount);

            repository.save(from);
            repository.save(to);
        } finally {
            lock.release(orderedIds[1]);
            lock.release(orderedIds[0]);
        }
    }
}

// Causal Consistency with Vector Clocks
public class CausalMessage {
    private final String content;
    private final VectorClock vectorClock;
    private final String senderId;

    // Message includes causal context
    public CausalMessage(String content, VectorClock clock, String senderId) {
        this.content = content;
        this.vectorClock = clock.increment(senderId);
        this.senderId = senderId;
    }
}

@Service
public class CausalMessageService {
    private final Map<String, VectorClock> clientClocks = new ConcurrentHashMap<>();
    private final PriorityQueue<CausalMessage> pendingMessages = new PriorityQueue<>(
        Comparator.comparing(m -> m.getVectorClock().sum())
    );

    public void deliver(CausalMessage message) {
        VectorClock localClock = clientClocks.get(message.getSenderId());

        // Only deliver if causal dependencies are satisfied
        if (message.getVectorClock().happensBefore(localClock)) {
            // Already seen or out of order - buffer
            pendingMessages.add(message);
        } else {
            // Deliver in causal order
            processMessage(message);
            clientClocks.merge(message.getSenderId(),
                message.getVectorClock(), VectorClock::merge);

            // Check if buffered messages can now be delivered
            deliverPendingMessages();
        }
    }
}
```

### Go (Different Consistency Levels)

```go
// Eventual Consistency
type ViewCountService struct {
    cache *cache.Cache
    repo  ViewCountRepository
    async chan viewCountUpdate
}

func (s *ViewCountService) GetViewCount(ctx context.Context, articleID string) (int64, error) {
    // Read from cache (eventually consistent)
    if count, ok := s.cache.Get(articleID); ok {
        return count.(int64), nil
    }

    // Cache miss - read from database
    count, err := s.repo.GetCount(ctx, articleID)
    if err != nil {
        return 0, err
    }

    s.cache.Set(articleID, count, time.Minute)
    return count, nil
}

func (s *ViewCountService) IncrementViewCount(articleID string) {
    // Fire and forget - eventual consistency
    select {
    case s.async <- viewCountUpdate{articleID: articleID}:
    default:
        // Channel full, drop update (acceptable for view counts)
    }
}

// Read-Your-Writes
type ProfileService struct {
    repo     ProfileRepository
    sessions SessionStore
}

func (s *ProfileService) UpdateProfile(ctx context.Context, userID string, update ProfileUpdate) error {
    profile, err := s.repo.Update(ctx, userID, update)
    if err != nil {
        return err
    }

    // Track write version for session
    sessionID := ctx.Value(sessionIDKey).(string)
    s.sessions.SetLastWriteVersion(sessionID, userID, profile.Version)
    return nil
}

func (s *ProfileService) GetProfile(ctx context.Context, userID string) (*Profile, error) {
    sessionID := ctx.Value(sessionIDKey).(string)
    minVersion := s.sessions.GetLastWriteVersion(sessionID, userID)

    // Read at least our last write
    return s.repo.FindByIDWithMinVersion(ctx, userID, minVersion)
}

// Strong Consistency with Distributed Lock
type AccountService struct {
    repo   AccountRepository
    locker DistributedLocker
}

func (s *AccountService) Transfer(ctx context.Context, fromID, toID string, amount Money) error {
    // Order locks to prevent deadlock
    ids := []string{fromID, toID}
    sort.Strings(ids)

    // Acquire locks
    for _, id := range ids {
        if err := s.locker.Lock(ctx, "account:"+id, 30*time.Second); err != nil {
            return fmt.Errorf("acquire lock %s: %w", id, err)
        }
        defer s.locker.Unlock(ctx, "account:"+id)
    }

    // Serialized access - strong consistency
    return s.repo.WithTransaction(ctx, func(tx *sql.Tx) error {
        from, err := s.repo.FindByIDForUpdate(ctx, tx, fromID)
        if err != nil {
            return err
        }

        to, err := s.repo.FindByIDForUpdate(ctx, tx, toID)
        if err != nil {
            return err
        }

        if err := from.Debit(amount); err != nil {
            return err
        }
        to.Credit(amount)

        if err := s.repo.Save(ctx, tx, from); err != nil {
            return err
        }
        return s.repo.Save(ctx, tx, to)
    })
}

// Monotonic Reads
type MonotonicReader struct {
    replicas   []ReplicaClient
    lastSeenAt map[string]int64 // Last seen timestamp per key
    mu         sync.RWMutex
}

func (r *MonotonicReader) Read(ctx context.Context, key string) ([]byte, error) {
    r.mu.RLock()
    minTimestamp := r.lastSeenAt[key]
    r.mu.RUnlock()

    // Try replicas until we find one with data at least as fresh
    for _, replica := range r.replicas {
        value, timestamp, err := replica.ReadWithTimestamp(ctx, key)
        if err != nil {
            continue
        }

        if timestamp >= minTimestamp {
            // Update last seen
            r.mu.Lock()
            if timestamp > r.lastSeenAt[key] {
                r.lastSeenAt[key] = timestamp
            }
            r.mu.Unlock()

            return value, nil
        }
    }

    return nil, ErrNoFreshReplica
}
```

## Choosing Consistency Level

| Scenario | Recommended Level | Why |
|----------|------------------|-----|
| View counts, likes | Eventual | High availability, stale OK |
| User profile edits | Read-Your-Writes | Users expect to see their changes |
| Social media feed | Causal | Related posts should appear in order |
| Shopping cart | Session consistency | User's cart should be consistent |
| Bank transfers | Linearizable | Must be absolutely correct |
| Distributed locks | Linearizable | Safety critical |
| Config propagation | Sequential | Order matters |
| Caching | Eventual | Stale is acceptable |

## Review Checklist

### Design
- [ ] **[BLOCKER]** Consistency requirements documented per operation
- [ ] **[MAJOR]** Trade-offs understood (CAP)
- [ ] **[MAJOR]** Failure modes identified
- [ ] **[MINOR]** Monitoring for consistency violations

### Implementation
- [ ] **[BLOCKER]** Critical operations use appropriate consistency
- [ ] **[MAJOR]** Eventually consistent reads don't assume freshness
- [ ] **[MAJOR]** Conflict resolution strategy defined
- [ ] **[MINOR]** Consistency level configurable where appropriate

### Anti-Patterns to Flag
- [ ] **[BLOCKER]** Financial operations with eventual consistency
- [ ] **[BLOCKER]** Assuming strong consistency without implementation
- [ ] **[MAJOR]** Mixing consistency levels without clear boundaries
- [ ] **[MAJOR]** No strategy for stale reads

## Common Mistakes

### 1. Assuming Consistency
```java
// BAD: Assumes strong consistency
order.setStatus(PAID);
orderRepo.save(order);
// Read from replica might still see PENDING!
Order fresh = orderRepo.findById(order.getId());
assert fresh.getStatus() == PAID;  // May fail!

// GOOD: Read from primary or use read-your-writes
Order fresh = orderRepo.findByIdFromPrimary(order.getId());
```

### 2. Wrong Level for Use Case
```java
// BAD: Eventually consistent for financial
viewCountService.increment(articleId);  // OK for views

// Same pattern for money - WRONG!
accountService.credit(accountId, amount);  // Needs strong consistency!

// GOOD: Strong consistency for financial
@Transactional(isolation = Isolation.SERIALIZABLE)
public void credit(String accountId, Money amount) {
    Account account = repo.findByIdForUpdate(accountId);
    account.credit(amount);
    repo.save(account);
}
```

### 3. Ignoring Stale Reads
```java
// BAD: Acting on potentially stale data
User user = cache.get(userId);  // Might be stale
if (user.isAdmin()) {  // Security decision on stale data!
    performAdminAction();
}

// GOOD: Fresh read for security decisions
User user = userRepo.findByIdFresh(userId);
if (user.isAdmin()) {
    performAdminAction();
}
```

## Related Patterns

| Pattern | Relationship |
|---------|-------------|
| **CQRS** | Different consistency for reads vs writes |
| **Event Sourcing** | Enables different consistency projections |
| **Saga** | Eventual consistency across services |
| **Idempotency** | Handles retries in eventually consistent systems |

## Popular Libraries

| Language | Library | Notes |
|----------|---------|-------|
| **Java** | [Apache ZooKeeper](https://zookeeper.apache.org/) | Coordination service for distributed consistency primitives |
| **Java** | [etcd Java Client](https://github.com/etcd-io/jetcd) | Strongly consistent key-value store client |
| **Java** | [Hazelcast](https://hazelcast.com/) | Distributed data structures with configurable consistency |
| **Go** | [etcd](https://etcd.io/) | Strongly consistent, distributed key-value store |
| **Go** | [Consul](https://www.consul.io/) | Service mesh with consistency guarantees |
| **Go** | [hashicorp/memberlist](https://github.com/hashicorp/memberlist) | Gossip-based membership for eventual consistency |
| **Python** | [kazoo](https://kazoo.readthedocs.io/) | ZooKeeper client for coordination primitives |
| **Python** | [python-etcd3](https://python-etcd3.readthedocs.io/) | etcd v3 client for strong consistency |
| **Multi** | [CockroachDB](https://www.cockroachlabs.com/) | Serializable distributed SQL database |
| **Multi** | [Redis](https://redis.io/) | In-memory store with configurable consistency (single-node strong, cluster eventual) |
| **Testing** | [Jepsen](https://jepsen.io/) | Distributed systems testing framework for consistency verification |

**Note**: Consistency guarantees are primarily determined by the database or coordination service you choose. Libraries help implement client-side consistency patterns (read-your-writes, monotonic reads) on top of these services.

## References

- Martin Kleppmann, "Designing Data-Intensive Applications" Chapters 5, 9
- Pat Helland, "Life Beyond Distributed Transactions"
- Werner Vogels, "Eventually Consistent" (ACM Queue)
- Jepsen Analysis: https://jepsen.io/analyses
