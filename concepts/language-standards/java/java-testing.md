# Java Testing Patterns

> Descriptive test names, AssertJ, mocking, and parameterized tests.
>
> **See also:** `java-immutability.md` (real objects vs mocks), `java-ai-antipatterns.md` (test anti-patterns)

## Descriptive Test Names

```java
// ❌ Anti-Pattern: Generic Test Names
@Test
public void testBuild() { }

@Test
public void testProcess() { }

@Test
public void test1() { }

// ✅ Correct: Descriptive Test Names
@Test
void shouldRejectArtifactWithoutGroupId() { }

@Test
void shouldRetryFailedBuildThreeTimes() { }

@Test
void shouldSkipProcessingWhenValidationFails() { }
```

## Test Behavior, Not Implementation

```java
// ❌ Anti-Pattern: Testing Implementation Details
@Test
void shouldCallRepositorySaveMethod() {
    service.createUser(user);
    verify(repository).save(any()); // Testing HOW, not WHAT
}

// ✅ Correct: Test Behavior, Not Implementation
@Test
void shouldPersistUserWhenCreated() {
    User user = service.createUser("John", "john@example.com");

    assertThat(user.getId()).isNotNull();
    assertThat(service.findById(user.getId()))
        .isPresent()
        .hasValueSatisfying(u -> {
            assertThat(u.getName()).isEqualTo("John");
            assertThat(u.getEmail()).isEqualTo("john@example.com");
        });
}
```

## Use AssertJ for Fluent Assertions

```java
// ❌ JUnit assertions
assertEquals(3, result.getErrors().size());
assertTrue(result.getErrors().contains("validation failed"));

// ✅ AssertJ assertions
assertThat(result.getErrors())
    .hasSize(3)
    .contains("validation failed")
    .allMatch(error -> error.length() > 0);

assertThat(buildResult)
    .isNotNull()
    .satisfies(r -> {
        assertThat(r.isSuccess()).isTrue();
        assertThat(r.getArtifactPath()).isPresent();
    });
```

## Mock Interfaces, Not Values

```java
// ❌ Anti-Pattern: Mock Everything
@Mock
private String artifactId; // Don't mock value objects!

@Mock
private List<String> tags; // Don't mock collections!

@Mock
private HttpClient httpClient; // OK to mock

// ✅ Correct: Mock Interfaces, Real Objects for Values
@Mock
private ArtifactRepository repository;

@Mock
private ValidationService validator;

// Real objects
private Artifact artifact;
private BuildConfig config;

@BeforeEach
void setUp() {
    artifact = new Artifact("com.example", "app", "1.0.0");
    config = BuildConfig.builder()
        .timeout(Duration.ofMinutes(5))
        .build();
}
```

## Parameterized Tests

```java
@ParameterizedTest
@MethodSource("invalidArtifacts")
void shouldRejectInvalidArtifacts(Artifact artifact, String expectedError) {
    var result = validator.validate(artifact);

    assertThat(result.isValid()).isFalse();
    assertThat(result.getErrors())
        .anyMatch(error -> error.contains(expectedError));
}

static Stream<Arguments> invalidArtifacts() {
    return Stream.of(
        Arguments.of(
            new Artifact(null, "app", "1.0"),
            "groupId cannot be null"
        ),
        Arguments.of(
            new Artifact("com.example", null, "1.0"),
            "artifactId cannot be null"
        ),
        Arguments.of(
            new Artifact("", "app", "1.0"),
            "groupId cannot be empty"
        )
    );
}
```

---

## Quick Reference

| Pattern | Problem | Fix |
|---------|---------|-----|
| `testBuild()` | Uninformative | `shouldDoXWhenY()` |
| `verify(mock).method()` | Tests implementation | Test behavior/outcome |
| JUnit `assertEquals` | Verbose | AssertJ `assertThat` |
| `@Mock String value` | Don't mock values | Use real objects |
| Duplicate test methods | Verbose | `@ParameterizedTest` |

---

## Testing Decision Trees

### When to Use @ParameterizedTest

```
Same logic, different inputs?
│
├─ Yes, 3+ cases → @ParameterizedTest with @MethodSource
├─ Yes, 2 cases → Consider separate methods (more readable)
└─ No → Regular @Test

Input source?
│
├─ Simple values → @ValueSource, @CsvSource
├─ Complex objects → @MethodSource
└─ Null/empty → @NullSource, @EmptySource
```

### Unit vs Integration Test

```
What are you testing?
│
├─ Single class in isolation → Unit test (mock dependencies)
├─ Multiple classes together → Integration test
├─ External system (DB, API) → Integration test with Testcontainers
└─ Full application flow → End-to-end test

Speed requirement?
│
├─ Must run in < 100ms → Unit test (mock slow dependencies)
└─ Can be slower → Integration test acceptable
```

### Mock vs Real Object

```
What type of object?
│
├─ Value object (data holder) → Real object
├─ Collection → Real object (List.of(), Map.of())
├─ Interface with external I/O → Mock
├─ Repository/Service → Mock (unless integration test)
└─ Simple utility → Real object

Are you testing behavior or interaction?
│
├─ Behavior (output given input) → Prefer real objects
└─ Interaction (was method called?) → Mock with verify()
    └─ Warning: verify() couples test to implementation
```

### Test Organization

| Test Type | Location | Naming | Speed |
|-----------|----------|--------|-------|
| Unit | `src/test/java` same package | `*Test.java` | < 100ms |
| Integration | `src/test/java` | `*IT.java` or `*IntegrationTest.java` | seconds |
| Architecture | `src/test/java` | `*ArchTest.java` | fast |
