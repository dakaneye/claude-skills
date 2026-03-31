# Terraform Module Design

## Standard Structure

```
module/
├── main.tf           # Primary resources
├── variables.tf      # Input variables
├── outputs.tf        # Output values
├── versions.tf       # Provider requirements
├── README.md         # Documentation
├── examples/
│   └── basic/
│       ├── main.tf
│       └── README.md
└── tests/
    └── main.tftest.hcl
```

## Module Sizing

| Size | Example | Verdict |
|------|---------|---------|
| Too small | Single security group rule | Just use resource |
| Right size | VPC with subnets, NAT, routes | Good abstraction |
| Too large | VPC + EC2 + RDS + S3 | Split into components |

## Composition Pattern

```hcl
# GOOD: Composable modules
module "network" {
  source = "./modules/vpc"
  cidr   = "10.0.0.0/16"
}

module "database" {
  source    = "./modules/rds"
  subnet_id = module.network.private_subnet_id
  vpc_id    = module.network.vpc_id
}

module "compute" {
  source    = "./modules/ec2"
  subnet_id = module.network.private_subnet_id
  db_host   = module.database.endpoint
}
```

## Dependency Injection

```hcl
# GOOD: Accept dependencies as inputs
variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
}

# BAD: Look up dependencies internally
data "aws_vpc" "main" {
  tags = { Name = "main" }  # Fragile - tag could change
}
```

## Variables Best Practice

```hcl
variable "instance_type" {
  description = "EC2 instance type for application servers"
  type        = string
  default     = "t3.medium"

  validation {
    condition     = can(regex("^t3\\.", var.instance_type))
    error_message = "Only t3 instance types are allowed."
  }
}

# No default for environment-specific values
variable "environment" {
  description = "Deployment environment"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Must be dev, staging, or prod."
  }
}
```

**Order:** description → type → default → validation

## Outputs Best Practice

```hcl
output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "database_password" {
  description = "Generated database password"
  value       = random_password.db.result
  sensitive   = true
}
```

## Locals Best Practice

```hcl
locals {
  # GOOD: Reusable computed values
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }

  # GOOD: Complex expressions
  private_subnets = {
    for idx, cidr in var.private_subnet_cidrs :
    "private-${idx}" => {
      cidr_block = cidr
      az         = data.aws_availability_zones.available.names[idx]
    }
  }
}

# BAD: Trivial single-use values
# local.name = var.name  # Just use var.name
```

## for_each vs count

```hcl
# BAD: count with list - index changes break resources
resource "aws_subnet" "private" {
  count      = length(var.subnet_cidrs)
  cidr_block = var.subnet_cidrs[count.index]
}

# GOOD: for_each with map - stable keys
resource "aws_subnet" "private" {
  for_each   = var.subnets
  cidr_block = each.value.cidr
  tags       = { Name = each.key }
}
```

## Module Sources

```hcl
# Local path
module "vpc" {
  source = "./modules/vpc"
}

# Git repository
module "vpc" {
  source = "git::https://github.com/org/terraform-modules.git//vpc?ref=v1.0.0"
}

# Terraform Registry
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
}

# S3 bucket
module "vpc" {
  source = "s3::https://s3-us-east-1.amazonaws.com/bucket/vpc.zip"
}
```

## Provider Passthrough

```hcl
# In module: declare expected providers
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.primary, aws.secondary]
    }
  }
}

# In root: pass providers
module "multi_region" {
  source = "./modules/multi-region"

  providers = {
    aws.primary   = aws
    aws.secondary = aws.west
  }
}
```

**Important:** Modules with provider configs can't use `for_each`, `count`, or `depends_on`.
