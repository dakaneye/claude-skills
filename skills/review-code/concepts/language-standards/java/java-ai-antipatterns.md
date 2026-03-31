# Java AI Anti-Patterns

> Common AI-generated code smells and performance issues.
>
> **See also:** `java-invest-checklist.md` (INVEST verification), all other focused files for correct patterns

## Unnecessary Null Checks on @NonNull

```java
// ❌ AI often generates this
public void process(@NonNull String input) {
    if (input == null) {
        throw new IllegalArgumentException("input cannot be null");
    }
    // ...
}

// ✅ Trust the annotation
public void process(@NonNull String input) {
    // No check needed - annotation enforces contract
}
```

## Over-Engineering Simple Logic

```java
// ❌ AI loves to create unnecessary abstractions
public interface StringProcessor {
    String process(String input);
}

public class UpperCaseProcessor implements StringProcessor {
    @Override
    public String process(String input) {
        return input.toUpperCase();
    }
}

// Usage
StringProcessor processor = new UpperCaseProcessor();
String result = processor.process(input);

// ✅ Just call the method
String result = input.toUpperCase();
```

## Catching and Rethrowing Same Exception

```java
// ❌ Pointless catch-and-rethrow
public void saveBuild(Build build) throws BuildException {
    try {
        repository.save(build);
    } catch (BuildException e) {
        throw e; // Why catch if you're just rethrowing?
    }
}

// ✅ Let it propagate
public void saveBuild(Build build) throws BuildException {
    repository.save(build);
}
```

## Empty Catch Blocks

```java
// ❌ Silent failure
try {
    processData(data);
} catch (ProcessingException e) {
    // TODO: handle exception
}

// ✅ At minimum, log it
try {
    processData(data);
} catch (ProcessingException e) {
    log.error("Failed to process data for {}", data.getId(), e);
    throw new ServiceException("Data processing failed", e);
}
```

## Redundant toString() Calls

```java
// ❌ AI adds unnecessary toString()
log.info("Processing artifact: " + artifact.toString());
String id = artifact.getId().toString();

// ✅ String concatenation calls toString() automatically
log.info("Processing artifact: {}", artifact);
String id = artifact.getId();
```

## String Concatenation in Loops

```java
// ❌ Creates many String objects
String result = "";
for (String item : items) {
    result += item + ",";
}

// ✅ Use StringBuilder
StringBuilder result = new StringBuilder();
for (String item : items) {
    result.append(item).append(",");
}
String finalResult = result.toString();

// ✅ Or better: use String.join()
String result = String.join(",", items);
```

## Boolean Parameter Confusion

```java
// ❌ What does true mean here?
service.processArtifact(artifact, true, false, true);

// ✅ Use builder or named parameters (records)
service.processArtifact(ProcessOptions.builder()
    .validateChecksum(true)
    .skipTests(false)
    .publishResults(true)
    .build());
```

## Old-Style Instanceof

```java
// ❌ Old-style instanceof
if (obj instanceof String) {
    String str = (String) obj;
    return str.length();
}

// ✅ Pattern matching (Java 16+)
if (obj instanceof String str) {
    return str.length();
}
```

## Comparing Strings with ==

```java
// ❌ Reference comparison
if (artifact.getType() == "jar") {
    // ...
}

// ✅ Value comparison
if ("jar".equals(artifact.getType())) {
    // ...
}
```

## Ignoring Return Values

```java
// ❌ String methods return new String, don't modify
String trimmed = input.trim();
input.toUpperCase(); // Result ignored!
return trimmed;

// ✅ Use the return value
return input.trim().toUpperCase();
```

---

## Performance Anti-Patterns

### O(n²) Loop

```java
// ❌ WRONG: List.contains inside loop = O(n²)
for (Order order : orders) {
    Customer customer = customers.stream()
        .filter(c -> c.getId().equals(order.getCustomerId()))
        .findFirst()
        .orElse(null);  // Linear search each time
    processOrder(order, customer);
}

// ✅ RIGHT: Build Map first = O(n)
Map<String, Customer> customerMap = customers.stream()
    .collect(Collectors.toMap(Customer::getId, Function.identity()));
for (Order order : orders) {
    Customer customer = customerMap.get(order.getCustomerId());
    processOrder(order, customer);
}
```

### Repeated Pattern Compilation

```java
// ❌ WRONG: Compiling Pattern on every call
public boolean isValid(String input) {
    return Pattern.matches("^[a-z0-9]+$", input);  // Compiles each time
}

// ✅ RIGHT: Compile once as constant
private static final Pattern VALID_PATTERN = Pattern.compile("^[a-z0-9]+$");

public boolean isValid(String input) {
    return VALID_PATTERN.matcher(input).matches();
}
```

### Boxing/Unboxing in Hot Paths

```java
// ❌ WRONG: Autoboxing in tight loops
List<Integer> values = new ArrayList<>();
for (int i = 0; i < 1_000_000; i++) {
    values.add(i);  // Autoboxing int -> Integer each time
}

// ✅ RIGHT: Use primitive collections or IntStream
int sum = IntStream.range(0, 100).sum();
```

---

## AI Detection Signals

| Signal | Description |
|--------|-------------|
| Null check on @NonNull | Redundant |
| `StringProcessor` interface | Over-engineering |
| `catch (E e) { throw e; }` | Pointless |
| `catch (E e) { }` | Silent failure |
| `x.toString()` in concatenation | Redundant |
| `+=` in loop for strings | O(n²) |
| `method(true, false, true)` | Boolean params |
| `instanceof` then cast | Use pattern matching |
| `== "string"` | Reference comparison |
| Ignored return value | Bug |

---

## Self-Correction Protocol

**Before submitting ANY Java code, scan for these signals:**

### Step 1: Quick Scan
Run through the AI Detection Signals table above. If any pattern found:
1. **Stop** - Do not present the code yet
2. **Fix** - Apply the correction from the table
3. **Re-scan** - Check for other signals

### Step 2: INVEST Verification
Verify against the INVEST checklist:
- [ ] **I**mmutability: Using records/`List.of()` where appropriate?
- [ ] **N**ull Safety: No `optional.get()` without check?
- [ ] **V**alidation: Fail fast in constructors?
- [ ] **E**xceptions: Chained with context, not swallowed?
- [ ] **S**tandard Library: Not reinventing existing utilities?
- [ ] **T**esting: Tests cover edge cases (null, empty, boundary)?

### Step 3: Final Check
Ask yourself:
1. "Would Joshua Bloch approve of this API design?"
2. "Is there a simpler approach I'm missing?"
3. "Can I remove any code and still have it work?"

**Only present code after passing all three steps.**

### Common Self-Corrections

| AI Tendency | Self-Correction |
|-------------|-----------------|
| Added null check on @NonNull param | Remove it - trust the annotation |
| Created `StringProcessor` interface | Just call `String.toUpperCase()` directly |
| Wrapped exception without adding context | Either add context or let it propagate |
| Used `Arrays.asList()` | Replace with `List.of()` |
| Used `instanceof` then cast | Use pattern matching: `if (obj instanceof String s)` |
| Added `toString()` in string concat | Remove it - automatic |
| Used `stream().forEach()` for simple loop | Use enhanced for loop |
