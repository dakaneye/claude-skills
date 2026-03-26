---
globs: "*.tf"
---

# Terraform Quality Rules (STATELOCK)

## Checklist

### S - Style
- `[BLOCKER]` Run `terraform fmt` before commit
- `[MAJOR]` snake_case for all names (resources, variables, outputs)
- `[MINOR]` 2-space indentation, `#` comments only

### T - Types & Descriptions
- `[BLOCKER]` Every variable has `type` and `description`
- `[BLOCKER]` Every output has `description`
- `[MAJOR]` Use `validation` blocks for input constraints

### A - Architecture
- `[BLOCKER]` Composable modules over monolithic configurations
- `[MAJOR]` Dependency injection: pass resources in, don't look them up
- `[MAJOR]` Standard structure: main.tf, variables.tf, outputs.tf, versions.tf

### T - Testing
- `[MAJOR]` Native `terraform test` for module validation
- `[MAJOR]` Pre-commit hooks: fmt, validate, tflint, trivy

### E - Environment Isolation
- `[BLOCKER]` Remote backend with state locking
- `[BLOCKER]` Separate state per environment
- `[MAJOR]` Encrypt state at rest, enable versioning

### L - Locking Versions
- `[BLOCKER]` Pin `required_version` for Terraform
- `[BLOCKER]` Pin provider versions with `~>` constraint
- `[MAJOR]` Commit `.terraform.lock.hcl`

### O - OIDC & Secrets
- `[BLOCKER]` No hardcoded credentials in code
- `[BLOCKER]` Use OIDC authentication where possible
- `[MAJOR]` Secrets from Vault/Secrets Manager, not tfvars

### C - CI/CD
- `[BLOCKER]` Plan artifacts saved and reviewed before apply
- `[MAJOR]` Policy as code (Sentinel/OPA) for guardrails

### K - Keep It Simple
- `[MAJOR]` Data sources over hardcoded IDs
- `[MAJOR]` `for_each` with maps, not `count` with lists
- `[MINOR]` Locals for reused computed values only

## AI Detection Signals

| Signal | Severity | What to Look For |
|--------|----------|------------------|
| Hardcoded AMI/subnet IDs | BLOCKER | `ami = "ami-12345"` instead of variable |
| Credentials in provider | BLOCKER | `access_key = "AKIA..."` |
| No backend block | BLOCKER | Local state = no locking |
| No version constraints | MAJOR | Missing `required_version` or provider versions |
| Monolithic module | MAJOR | Single module creates VPC + EC2 + RDS + S3 |
| `count` with list index | MAJOR | `count = length(var.list)` loses key association |
| Missing lifecycle protection | MAJOR | Production DB without `prevent_destroy` |
| `terraform apply -auto-approve` | MAJOR | No plan review in production |
| `-target` in production | MAJOR | Partial applies cause drift |
| Wrapper module for one resource | MINOR | Over-abstraction |
| Redundant locals | MINOR | `local.name = var.name` |

## Top 3 Anti-Pattern Examples

### Hardcoded values instead of data sources
```hcl
# BAD
resource "aws_instance" "app" {
  ami           = "ami-12345678"
  subnet_id     = "subnet-abc123"
}

# GOOD
resource "aws_instance" "app" {
  ami           = data.aws_ami.ubuntu.id
  subnet_id     = var.subnet_id
}
```

### count with list index
```hcl
# BAD - removing item 0 destroys all subsequent resources
resource "aws_subnet" "private" {
  count      = length(var.subnet_cidrs)
  cidr_block = var.subnet_cidrs[count.index]
}

# GOOD - stable keys
resource "aws_subnet" "private" {
  for_each   = var.subnets
  cidr_block = each.value.cidr
  tags       = { Name = each.key }
}
```

### No lifecycle protection on critical resources
```hcl
# BAD
resource "aws_db_instance" "prod" {
  identifier = "production-db"
}

# GOOD
resource "aws_db_instance" "prod" {
  identifier          = "production-db"
  deletion_protection = true

  lifecycle {
    prevent_destroy = true
  }
}
```

## Deep Dives
See `~/.claude/skills/review-code/` (terraform-*.md, state.md, modules.md, security.md, testing.md, anti-patterns.md files) for state management, module design, security, testing, and anti-patterns.
