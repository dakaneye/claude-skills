# Code Review Methodology (Staff-Level)

> Comprehensive approach to reviewing code for quality, security, performance, maintainability, and PR hygiene.

## Review Dimensions

### 0. PR Scope & Hygiene (REQUIRED - Check First)

Before reviewing code quality, assess PR hygiene:

#### Size Assessment
- **Ideal**: <150 LOC (easy to review, quick feedback)
- **Acceptable**: 150-250 LOC (reviewable but pushing limits)
- **Too Large**: >250 LOC (request split - blocker for Staff+ engineers)

#### Scope Coherence
- Does every file change serve the PR's stated purpose?
- Are there unrelated changes bundled in?
- Is there evidence of "AI-spray" (touching many files for a simple fix)?

#### AI-Spray Detection
**Red Flags**:
- 10+ files for a "simple fix"
- Adding comprehensive docs to every function in scope
- Refactoring surrounding code that wasn't broken
- New utility functions duplicating existing functionality
- "While I was here" changes

**Green Flags**:
- Focused changes solving one problem
- Commits telling a coherent story
- Tests covering actual change, not everything nearby

#### Required Assessment Statement
Every review MUST include one of:
- "This PR is **human-intentional**: focused scope, coherent changes, appropriate size."
- "This PR shows **AI-spray patterns**: [issues]. Recommend splitting/trimming."
- "This PR is **mixed**: core changes intentional but includes [X] unrelated changes."

### 1. Correctness
- **Logic errors**: Off-by-one, null handling, edge cases
- **API contracts**: Proper use of interfaces and protocols
- **Business requirements**: Meets specified functionality
- **Error handling**: Graceful degradation and recovery
- **Silent behavioral changes**: Does this change default behavior? If no config is present, does behavior change?
- **Consistent return shapes**: Do all code paths return the same structure?

### 2. Security
- **Input validation**: Sanitization and bounds checking
- **Authentication/Authorization**: Proper access controls
- **Secrets management**: No hardcoded credentials
- **OWASP Top 10**: SQL injection, XSS, CSRF protection
- **Dependencies**: Known vulnerabilities in libraries

### 3. Performance
- **Algorithm complexity**: O(n) analysis where relevant
- **Resource usage**: Memory leaks, connection pooling
- **Caching strategy**: Appropriate use of caching
- **Database queries**: N+1 problems, missing indexes
- **Async patterns**: Proper concurrency handling

### 4. Maintainability
- **Code clarity**: Self-documenting, clear naming
- **DRY principle**: Appropriate abstraction level
- **SOLID principles**: Single responsibility, dependency injection
- **Test coverage**: Unit, integration, e2e tests
- **Documentation**: Comments where necessary, API docs

### 5. Style & Consistency
- **Code formatting**: Consistent with project style
- **Naming conventions**: Follow language idioms
- **File organization**: Logical structure
- **Import ordering**: Consistent grouping
- **Library consistency**: Use same library for same purpose across codebase (e.g., don't mix minimatch and micromatch)

### 6. Code Hygiene (Staff-Level Patterns)

These patterns are commonly missed by AI-generated code:

#### Redundant Parameters
Check if methods receive data that's already available on `this`:
```javascript
// 🔴 BAD: buildConfig passed when this.build.config exists
verify(buildConfig, source, build) {
  const patterns = buildConfig.allow?.binaryFiles; // redundant!
}

// ✅ GOOD: Use context already available
verify(source, build) {
  const patterns = this.build.config.allow?.binaryFiles;
}
```

#### Dead Code Detection
Look for functions that are defined but never called:
```javascript
// 🔴 BAD: Function defined but never invoked anywhere
export function enforceBinaryContent(source, build) {
  // This function exists but grep shows no callers
}
```

#### Silent Behavioral Changes (Security Critical)
When default behavior changes without explicit config:
```javascript
// 🔴 SECURITY REGRESSION: Previously packages failed without config
// Now they pass silently when allow.binaryFiles is undefined
if (!patterns?.length) {
  return { passed: true }; // SILENT CHANGE - should this default to fail?
}

// ✅ EXPLICIT: Preserve previous behavior as default
if (!patterns?.length) {
  return originalBehavior(); // Explicit about what happens
}
```

#### Inconsistent Return Shapes
All code paths should return same structure:
```javascript
// 🔴 BAD: Different shapes from different paths
if (passed) return { passed: true, file, detail: { patterns } };
if (skipped) return { passed: true, file }; // Missing detail!

// ✅ GOOD: Consistent shape always
if (passed) return { passed: true, file, detail: { patterns } };
if (skipped) return { passed: true, file, detail: { skipped: true } };
```

#### Duplicate Configuration Fetching
Config should be fetched once and reused:
```javascript
// 🔴 BAD: Same config fetched in multiple places
const config1 = ecopkg.loadPackageConfig(spec);
// ... later in same flow ...
const config2 = ecopkg.loadPackageConfig(spec); // duplicate!

// ✅ GOOD: Fetch once, pass as needed
const config = ecopkg.loadPackageConfig(spec);
processor.run(config);
```

## Review Process

### Pre-Review Checklist
1. Tests pass locally
2. Linting/formatting applied
3. Documentation updated
4. Commits are logical and well-messaged

### Review Workflow
1. **Context understanding**: Read PR description and related issues
2. **High-level scan**: Understand overall changes
3. **Detailed review**: Line-by-line analysis
4. **Test review**: Verify test coverage and quality
5. **Run locally**: Test functionality when needed
6. **Feedback synthesis**: Prioritize and categorize issues

## Feedback Categories

### 🔴 **Blocker** (Must Fix)
- Security vulnerabilities
- Data loss risks
- Breaking changes without migration
- Critical logic errors
- **PR too large (>250 LOC) or unfocused**
- **Unrelated changes bundled**

### 🟡 **Major** (Should Fix)
- Performance regressions
- Missing error handling
- Inadequate test coverage
- Accessibility issues
- **AI-spray patterns detected**
- **Silent behavioral changes** without explicit opt-in
- **Missing edge case tests** (e.g., empty inputs, boundary conditions, indicator-only scenarios)

### 🟢 **Minor** (Consider)
- Style improvements
- Refactoring opportunities
- Documentation enhancements
- Nice-to-have features

### 💭 **Discussion**
- Architecture decisions
- Alternative approaches
- Future considerations

## Feedback Guidelines

### Constructive Feedback
- **Specific**: Reference exact lines/files
- **Actionable**: Provide clear suggestions
- **Educational**: Explain the "why"
- **Respectful**: Focus on code, not person

### Example Templates
```
🔴 Security Issue: This SQL query is vulnerable to injection.
Suggestion: Use parameterized queries:
`db.query('SELECT * FROM users WHERE id = ?', [userId])`

🟡 Performance: This nested loop creates O(n²) complexity.
Consider using a Map for O(n) lookup instead.

🟢 Style: Consider extracting this logic to a named function
for better readability and testability.
```

## Special Considerations

### PR Size (Staff-Level Standards)
- **Ideal**: <150 LOC - approve quickly
- **Acceptable**: 150-250 LOC - review carefully
- **Request Split**: >250 LOC - this is a blocker
- **Focus areas**: Prioritize critical paths
- **Incremental review**: Review in multiple passes

### Team Dynamics
- **Learning opportunity**: Share knowledge
- **Consensus building**: Discuss contentious points
- **Documentation**: Record decisions for future reference

## Staff-Level Recommendation Section

Every review MUST conclude with:

```markdown
## Staff-Level Assessment

### PR Hygiene
- **Size**: [X LOC] - [Ideal/Acceptable/Too Large]
- **Intent**: [Human-intentional / AI-spray / Mixed]
- **Scope**: [Focused / Includes unrelated changes]

### Recommendation
[ ] Approve - Ready to merge
[ ] Approve with suggestions
[ ] Request changes - Issues must be addressed
[ ] Request split - PR too large or includes unrelated changes

### If Split Needed
Recommend:
- PR 1: [Core change] (~X LOC)
- PR 2: [Other concern] (~Y LOC)
```

## Tools Integration
- **GitHub PR review**: Use review features effectively
- **CI/CD results**: Check automated test results
- **Security scanners**: Review scanner outputs
- **Code coverage**: Verify coverage reports

## Post-Review
- **Follow-up**: Verify fixes were applied
- **Patterns**: Document recurring issues
- **Team learning**: Share insights in team meetings