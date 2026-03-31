# Terraform Testing

## Native Terraform Test (1.6+)

### Basic Test

```hcl
# tests/vpc.tftest.hcl
run "create_vpc" {
  command = apply

  assert {
    condition     = aws_vpc.main.cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR block is incorrect"
  }

  assert {
    condition     = length(aws_subnet.private) == 3
    error_message = "Expected 3 private subnets"
  }
}
```

### Plan-Only Test (Unit Test)

```hcl
run "validate_tags" {
  command = plan  # No actual resources created

  assert {
    condition     = aws_vpc.main.tags["Environment"] == var.environment
    error_message = "Environment tag not set correctly"
  }
}
```

### Test Variables

```hcl
run "test_with_vars" {
  command = plan

  variables {
    environment   = "test"
    instance_type = "t3.micro"
  }

  assert {
    condition     = aws_instance.app.instance_type == "t3.micro"
    error_message = "Instance type not set correctly"
  }
}
```

### Module Testing

```hcl
run "test_module" {
  command = apply

  module {
    source = "./modules/vpc"
  }

  variables {
    cidr_block = "10.0.0.0/16"
  }

  assert {
    condition     = output.vpc_id != ""
    error_message = "VPC ID should not be empty"
  }
}
```

### Running Tests

```bash
# Run all tests
terraform test

# Run specific test file
terraform test -filter=tests/vpc.tftest.hcl

# Verbose output
terraform test -verbose
```

## Terratest (Go-based)

### Basic Test

```go
// test/vpc_test.go
package test

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestVPC(t *testing.T) {
    terraformOptions := &terraform.Options{
        TerraformDir: "../examples/vpc",
        Vars: map[string]interface{}{
            "environment": "test",
            "cidr_block":  "10.0.0.0/16",
        },
    }

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)

    vpcId := terraform.Output(t, terraformOptions, "vpc_id")
    assert.NotEmpty(t, vpcId)
}
```

### Testing Actual AWS Resources

```go
func TestVPCWithAWS(t *testing.T) {
    terraformOptions := &terraform.Options{
        TerraformDir: "../examples/vpc",
    }

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)

    vpcId := terraform.Output(t, terraformOptions, "vpc_id")

    // Query actual AWS
    vpc := aws.GetVpc(t, vpcId, "us-east-1")
    assert.Equal(t, "10.0.0.0/16", vpc.CidrBlock)
}
```

### Running Terratest

```bash
cd test
go test -v -timeout 30m
```

## Comparison

| Feature | Native Test | Terratest |
|---------|-------------|-----------|
| Language | HCL | Go |
| Learning curve | Low | Higher |
| Validates | Terraform state | Actual cloud resources |
| Speed | Faster | Slower |
| Flexibility | Assertions only | Full Go |
| Best for | Module authors | Integration tests |

## Pre-Commit Validation

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.88.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_tflint
        args:
          - --args=--config=__GIT_WORKING_DIR__/.tflint.hcl
      - id: terraform_trivy
```

## TFLint Configuration

```hcl
# .tflint.hcl
plugin "aws" {
  enabled = true
  version = "0.27.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

rule "terraform_naming_convention" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}
```

## CI Test Pipeline

```yaml
# .github/workflows/test.yml
name: Terraform Tests

on: [pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3

      - name: Format Check
        run: terraform fmt -check -recursive

      - name: Validate
        run: |
          terraform init -backend=false
          terraform validate

      - name: TFLint
        uses: terraform-linters/setup-tflint@v4
      - run: tflint --recursive

      - name: Trivy Scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: config
          scan-ref: .

      - name: Terraform Test
        run: terraform test
```
