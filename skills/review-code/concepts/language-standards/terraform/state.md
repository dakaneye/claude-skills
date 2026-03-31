# Terraform State Management

## Remote Backend Configuration

### AWS S3 + DynamoDB

```hcl
terraform {
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "prod/networking/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

### GCP GCS

```hcl
terraform {
  backend "gcs" {
    bucket = "company-terraform-state"
    prefix = "prod/networking"
  }
}
```

### Azure Storage

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstate12345"
    container_name       = "tfstate"
    key                  = "prod.terraform.tfstate"
  }
}
```

## Workspaces vs Directories

| Approach | Use When | Avoid When |
|----------|----------|------------|
| **Workspaces** | Same config, different instances | Different backends needed |
| **Directories** | Different backends, significant config differences | Simple env switching |

**Workspace limitation:** All workspaces share the same backend block.

## State Security Checklist

- [ ] Encryption at rest enabled
- [ ] Versioning enabled for recovery
- [ ] State locking enabled
- [ ] IAM policies restrict access
- [ ] Access logging enabled
- [ ] `*.tfstate*` in `.gitignore`

## Cross-State Data Sharing

```hcl
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "company-terraform-state"
    key    = "prod/networking/terraform.tfstate"
    region = "us-east-1"
  }
}

# Use outputs from other state
resource "aws_instance" "app" {
  subnet_id = data.terraform_remote_state.network.outputs.private_subnet_id
}
```

## State Commands

```bash
# List resources in state
terraform state list

# Show specific resource
terraform state show aws_instance.app

# Move resource (rename)
terraform state mv aws_instance.old aws_instance.new

# Move into module
terraform state mv aws_vpc.main module.network.aws_vpc.this

# Remove from state (resource still exists)
terraform state rm aws_instance.orphaned

# Pull remote state to local
terraform state pull > backup.tfstate

# Push local state to remote (DANGEROUS)
terraform state push backup.tfstate
```

## Import Strategies

### Import Block (1.5+)

```hcl
import {
  to = aws_s3_bucket.existing
  id = "my-existing-bucket"
}
```

```bash
# Generate configuration
terraform plan -generate-config-out=generated.tf
```

### Moved Block (Refactoring)

```hcl
moved {
  from = aws_instance.old_name
  to   = aws_instance.new_name
}

moved {
  from = aws_vpc.main
  to   = module.networking.aws_vpc.this
}
```

## Drift Detection

```bash
# Check for drift (exit code 2 = drift detected)
terraform plan -detailed-exitcode

# Refresh-only mode
terraform apply -refresh-only
```
