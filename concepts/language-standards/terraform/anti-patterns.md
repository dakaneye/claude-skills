# Terraform Anti-Patterns

## 1. Monolithic State Files

```hcl
# BAD: Everything in one state
# - Slow plans (500+ resources = minutes)
# - Large blast radius
# - Team contention on locks

# GOOD: Split by service/component
# services/api/
# services/web/
# infrastructure/networking/
# infrastructure/database/
```

## 2. Hardcoded Values

```hcl
# BAD
resource "aws_instance" "app" {
  ami           = "ami-12345678"
  instance_type = "t3.medium"
  subnet_id     = "subnet-abc123"
}

# GOOD
resource "aws_instance" "app" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
}
```

## 3. Credentials in Code

```hcl
# BLOCKER - Never do this
provider "aws" {
  access_key = "AKIAIOSFODNN7EXAMPLE"
  secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
}

# GOOD - Environment or OIDC
provider "aws" {
  region = "us-east-1"
}
```

## 4. Local State

```hcl
# BAD: No backend = local state
# Risk: State loss, no locking, no collaboration

# GOOD: Always remote backend
terraform {
  backend "s3" {
    bucket         = "terraform-state"
    key            = "prod/terraform.tfstate"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

## 5. No Version Pinning

```hcl
# BAD
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # No version = any version = breakage
    }
  }
}

# GOOD
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.31.0"
    }
  }
}
```

## 6. count with Lists

```hcl
# BAD: Index changes break resources
resource "aws_subnet" "private" {
  count      = length(var.subnet_cidrs)
  cidr_block = var.subnet_cidrs[count.index]
}
# If you remove item 0, all subsequent subnets are destroyed/recreated

# GOOD: for_each with stable keys
resource "aws_subnet" "private" {
  for_each   = var.subnets  # map with stable keys
  cidr_block = each.value.cidr
  tags       = { Name = each.key }
}
```

## 7. Copy-Paste Instead of Modules

```hcl
# BAD: Duplicated code
# dev/main.tf, staging/main.tf, prod/main.tf
# all have identical VPC code

# GOOD: Single module, multiple calls
module "vpc" {
  source      = "../modules/vpc"
  environment = var.environment
  cidr        = var.vpc_cidr
}
```

## 8. Manual Console Changes

```bash
# BAD: ClickOps causes drift
# Resources modified in AWS Console

# GOOD: All changes through Terraform
# - Regular drift detection
# - Import unmanaged resources
terraform import aws_instance.manual i-12345
```

## 9. No Lifecycle Protection

```hcl
# BAD: Production DB can be deleted
resource "aws_db_instance" "prod" {
  identifier = "production-db"
}

# GOOD: Protect critical resources
resource "aws_db_instance" "prod" {
  identifier          = "production-db"
  deletion_protection = true

  lifecycle {
    prevent_destroy = true
  }
}
```

## 10. Auto-Approve in Production

```bash
# BAD
terraform apply -auto-approve  # No review!

# GOOD
terraform plan -out=tfplan
# Review the plan
terraform apply tfplan
```

## 11. Targeted Applies in Production

```bash
# BAD: Causes drift
terraform apply -target=module.app

# GOOD: Full apply always
terraform apply tfplan
```

## 12. Data Source Dependencies

```hcl
# BAD: Fragile tag lookup
data "aws_vpc" "main" {
  tags = { Name = "main" }  # Tag could change
}

# GOOD: Explicit reference or remote state
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "state"
    key    = "network/terraform.tfstate"
  }
}
```

## 13. Redundant Locals

```hcl
# BAD: Trivial single-use values
locals {
  bucket_name = var.bucket_name  # Just use var.bucket_name
}

# GOOD: Computed/reused values only
locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
```

## 14. Complex Dynamic Keys

```hcl
# BAD: Unknown keys at plan time
resource "aws_instance" "dynamic" {
  for_each = toset(data.external.instances.result)
}
# Error: for_each keys must be known at plan

# GOOD: Static keys
resource "aws_instance" "dynamic" {
  for_each = {
    for k, v in local.instances : k => v
    # Keys must be literals or computed from known values
  }
}
```

## 15. Ignoring Lock File

```bash
# BAD: Not committing lock file
echo ".terraform.lock.hcl" >> .gitignore

# GOOD: Commit lock file
git add .terraform.lock.hcl
git commit -m "chore: update provider lock file"
```

## AI-Generated Anti-Patterns

| Signal | Problem |
|--------|---------|
| Over-parameterized modules | 50+ variables for "flexibility" |
| Wrapper modules around single resource | `module "bucket"` wrapping one `aws_s3_bucket` |
| Excessive comments | `# Create VPC` above `resource "aws_vpc"` |
| Unused variables | Variables defined but never referenced |
| `try()` everywhere | Error suppression instead of fixing |
| `terraform_data` for side effects | Shell scripts embedded in Terraform |
