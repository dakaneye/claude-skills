# Terraform Security

## Sensitive Variables

```hcl
variable "database_password" {
  description = "Password for the database"
  type        = string
  sensitive   = true  # Redacts from CLI output
}
```

## Never Hardcode Credentials

```hcl
# BLOCKER - Never do this
provider "aws" {
  access_key = "AKIAIOSFODNN7EXAMPLE"      # NO!
  secret_key = "wJalrXUtnFEMI/K7MDENG..."  # NO!
}

# GOOD - Use environment or OIDC
provider "aws" {
  region = "us-east-1"
  # Credentials from AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY
  # or instance role, or OIDC
}
```

## OIDC Authentication

### GitHub Actions

```yaml
# .github/workflows/terraform.yml
permissions:
  id-token: write
  contents: read

steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::123456789:role/GitHubActionsRole
      aws-region: us-east-1
```

### GitLab CI

```yaml
assume_role:
  id_tokens:
    GITLAB_OIDC_TOKEN:
      aud: https://gitlab.com
  script:
    - >
      export $(printf "AWS_ACCESS_KEY_ID=%s AWS_SECRET_ACCESS_KEY=%s AWS_SESSION_TOKEN=%s"
      $(aws sts assume-role-with-web-identity
      --role-arn $ROLE_ARN
      --role-session-name "GitLabRunner"
      --web-identity-token $GITLAB_OIDC_TOKEN
      --query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]"
      --output text))
```

## Secrets Management

### HashiCorp Vault

```hcl
data "vault_generic_secret" "db" {
  path = "secret/database/prod"
}

resource "aws_db_instance" "main" {
  password = data.vault_generic_secret.db.data["password"]
}
```

### AWS Secrets Manager

```hcl
data "aws_secretsmanager_secret_version" "db" {
  secret_id = "prod/database/credentials"
}

locals {
  db_creds = jsondecode(data.aws_secretsmanager_secret_version.db.secret_string)
}

resource "aws_db_instance" "main" {
  password = local.db_creds.password
}
```

### GCP Secret Manager

```hcl
data "google_secret_manager_secret_version" "db" {
  secret = "database-password"
}

resource "google_sql_user" "main" {
  password = data.google_secret_manager_secret_version.db.secret_data
}
```

## Security Scanning Tools

| Tool | Focus | Command |
|------|-------|---------|
| **Trivy** | Unified scanner | `trivy config .` |
| **Checkov** | Graph-based | `checkov -d .` |
| **TFLint** | Linting | `tflint` |
| **tfsec** | Security | Absorbed into Trivy |

## Pre-Commit Hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.88.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_tflint
      - id: terraform_trivy
```

## State Security

- [ ] Encryption at rest (S3 bucket encryption, GCS)
- [ ] Enable versioning for recovery
- [ ] Enable state locking
- [ ] Restrict IAM access (state contains secrets!)
- [ ] Never commit `*.tfstate*` to git
- [ ] Audit state access

## Lifecycle Protection

```hcl
resource "aws_db_instance" "prod" {
  identifier          = "production-db"
  deletion_protection = true

  lifecycle {
    prevent_destroy = true
  }
}
```

## Policy as Code

### OPA/Conftest

```rego
# policy/s3.rego
package terraform

deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_s3_bucket"
  resource.change.after.acl == "public-read"
  msg := sprintf("S3 bucket %s cannot be public", [resource.address])
}
```

```bash
terraform show -json tfplan > tfplan.json
conftest test tfplan.json --policy policy/
```

### Sentinel (HCP Terraform)

```hcl
# prevent-public-s3.sentinel
import "tfplan/v2" as tfplan

main = rule {
  all tfplan.resource_changes as _, rc {
    rc.type is "aws_s3_bucket" implies
      rc.change.after.acl is not "public-read"
  }
}
```
