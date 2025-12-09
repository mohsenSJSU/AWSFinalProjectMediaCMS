# Resource Tagging Policy

**Author:** Mohsen Minai  
**Date:** December 2024  
**Project:** MediaCMS on AWS

---

## Overview

This document defines the mandatory resource tagging policy for the MediaCMS infrastructure. Consistent tagging enables cost tracking, resource management, compliance auditing, and operational efficiency.

---

## Mandatory Tags

All AWS resources created by this infrastructure **MUST** have the following tags:

| Tag Key | Example Value | Purpose | Source |
|---------|---------------|---------|--------|
| `Project` | mediacms | Identifies the project | Variable |
| `Environment` | production | Identifies environment (dev/staging/prod) | Variable |
| `Owner` | Mohsen Minai | Contact person for resource | Hardcoded |
| `ManagedBy` | Terraform | How resource is provisioned | Hardcoded |
| `CostCenter` | MediaCMS-Infrastructure | Cost allocation | Hardcoded |
| `Compliance` | CMPE-281-FinalProject | Compliance requirement | Hardcoded |

---

## Implementation

### Provider-Level Default Tags

**File:** `terraform/provider.tf`

```hcl
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Owner       = "Mohsen Minai"
      ManagedBy   = "Terraform"
      CostCenter  = "MediaCMS-Infrastructure"
      Compliance  = "CMPE-281-FinalProject"
    }
  }
}
```

**Benefits:**
- ✅ **Automatic inheritance** - All resources get these tags automatically
- ✅ **No duplication** - Don't need to specify tags in each resource
- ✅ **Consistency** - Impossible to forget tags or use wrong format
- ✅ **Easy updates** - Change in one place applies everywhere

---

## Environment Variable

**File:** `terraform/variables.tf`

```hcl
variable "environment" {
  description = "Environment name (e.g., dev, staging, production)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}
```

**Features:**
- ✅ **Validation** - Only allows valid environment names
- ✅ **Type safety** - Must be a string
- ✅ **Default value** - Production by default for safety
- ✅ **Documentation** - Clear description of purpose

---

## Tag Usage by Resource Type

### Compute Resources
- **ECS Cluster:** All tags applied
- **ECS Service:** All tags applied
- **ECS Task Definition:** All tags applied

### Network Resources
- **VPC:** All tags applied
- **Subnets:** All tags applied + specific Name tag
- **Security Groups:** All tags applied + specific Name tag
- **NAT Gateways:** All tags applied
- **Internet Gateway:** All tags applied
- **Route Tables:** All tags applied

### Database Resources
- **RDS Instance:** All tags applied
- **RDS Subnet Group:** All tags applied
- **ElastiCache Cluster:** All tags applied
- **ElastiCache Subnet Group:** All tags applied

### Storage Resources
- **S3 Bucket:** All tags applied
- **Secrets Manager Secret:** All tags applied

### Monitoring Resources
- **CloudWatch Log Groups:** All tags applied
- **CloudWatch Alarms:** All tags applied
- **SNS Topics:** All tags applied

### Load Balancing
- **Application Load Balancer:** All tags applied
- **Target Groups:** All tags applied

---

## Querying Resources by Tags

### Find All Project Resources

```bash
# Using AWS CLI
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=mediacms \
  --query 'ResourceTagMappingList[*].[ResourceARN]' \
  --output table
```

### Find Resources by Environment

```bash
# Production resources only
aws resourcegroupstaggingapi get-resources \
  --tag-filters \
    Key=Project,Values=mediacms \
    Key=Environment,Values=production \
  --output table
```

### Cost Allocation by Tags

```bash
# Get cost breakdown by Project
aws ce get-cost-and-usage \
  --time-period Start=2024-12-01,End=2024-12-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=TAG,Key=Project
```

### Find Untagged Resources

```bash
# Resources missing Project tag
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values= \
  --output table
```

---

## Tag Enforcement

### Terraform Validation

Environment validation is built-in:

```hcl
variable "environment" {
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}
```

If you try to use an invalid environment:
```bash
terraform apply -var="environment=test"

# Error: Invalid value for variable
# Environment must be dev, staging, or production.
```

### AWS Config Rules (Future Enhancement)

For production deployments, consider AWS Config rules:

```hcl
resource "aws_config_config_rule" "required_tags" {
  name = "required-tags"

  source {
    owner             = "AWS"
    source_identifier = "REQUIRED_TAGS"
  }

  input_parameters = jsonencode({
    tag1Key = "Project"
    tag2Key = "Environment"
    tag3Key = "Owner"
    tag4Key = "ManagedBy"
  })
}
```

---

## Multi-Environment Strategy

### Using Terraform Workspaces

```bash
# Create workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace new production

# Switch environments
terraform workspace select dev

# Apply with environment-specific values
terraform apply -var="environment=dev" -var="ecs_desired_count=1"
```

### Environment-Specific Variable Files

**File:** `terraform/environments/dev.tfvars`
```hcl
environment       = "dev"
ecs_desired_count = 1
ecs_min_capacity  = 1
ecs_max_capacity  = 2
db_instance_class = "db.t3.small"
redis_node_type   = "cache.t3.micro"
```

**File:** `terraform/environments/production.tfvars`
```hcl
environment       = "production"
ecs_desired_count = 2
ecs_min_capacity  = 2
ecs_max_capacity  = 10
db_instance_class = "db.t3.medium"
redis_node_type   = "cache.t3.micro"
```

**Deploy:**
```bash
terraform apply -var-file="environments/dev.tfvars"
```

---

## Cost Tracking

### Enable Cost Allocation Tags

1. Go to AWS Billing Console
2. Navigate to "Cost Allocation Tags"
3. Activate these tags:
   - `Project`
   - `Environment`
   - `Owner`
   - `CostCenter`

### View Costs by Tag

After 24 hours, tags appear in Cost Explorer:

1. Open Cost Explorer
2. Group by: Tag → Project
3. Filter by: Environment = production
4. Time range: Last 30 days

**Example Output:**
```
Project: mediacms
├── ECS: $73/month
├── RDS: $120/month
├── ElastiCache: $50/month
├── NAT Gateway: $100/month
└── ALB: $23/month
Total: $366/month
```

---

## Compliance & Auditing

### Generate Resource Inventory

```bash
# Create CSV of all tagged resources
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=mediacms \
  --query 'ResourceTagMappingList[*].[ResourceARN,Tags[?Key==`Environment`].Value | [0]]' \
  --output text > mediacms-inventory.csv
```

### Verify Tag Compliance

```bash
# Check if all resources have required tags
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=mediacms \
  | jq '.ResourceTagMappingList[] | 
    select(.Tags | length < 6) | 
    .ResourceARN'

# Expected: Empty output (all resources have 6+ tags)
```

### Audit Trail

All tag changes are logged in CloudTrail:

```json
{
  "eventName": "CreateTags",
  "eventSource": "ec2.amazonaws.com",
  "requestParameters": {
    "resourcesSet": {
      "items": [{"resourceId": "i-xxxxx"}]
    },
    "tagSet": {
      "items": [
        {"key": "Project", "value": "mediacms"},
        {"key": "Environment", "value": "production"}
      ]
    }
  }
}
```

---

## Resource Cleanup

### Delete All Project Resources

```bash
# Option 1: Terraform destroy
terraform destroy

# Option 2: Tag-based deletion (DANGEROUS!)
# Get resource ARNs
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=mediacms \
  --query 'ResourceTagMappingList[*].ResourceARN'

# Then manually delete each resource
# (Recommended: Use Terraform destroy instead)
```

### Delete Single Environment

```bash
# Switch workspace
terraform workspace select dev

# Destroy dev environment only
terraform destroy -var-file="environments/dev.tfvars"
```

---

## Best Practices

### DO ✅

1. **Use provider default_tags** - Automatic, consistent, and impossible to forget
2. **Validate tag values** - Use Terraform validation blocks
3. **Document tag purpose** - Clear descriptions in variables
4. **Enable cost allocation tags** - Track spending by project/environment
5. **Audit regularly** - Check for untagged or mis-tagged resources
6. **Use consistent naming** - PascalCase for tag keys, lowercase for values

### DON'T ❌

1. **Don't hardcode tags in every resource** - Use provider default_tags instead
2. **Don't use freeform text** - Validate with allowed values
3. **Don't mix tag formats** - Stay consistent (e.g., "Environment" not "Env" or "environment")
4. **Don't forget case sensitivity** - AWS tags are case-sensitive
5. **Don't use special characters** - Stick to letters, numbers, hyphens, underscores
6. **Don't create orphaned resources** - Always use Terraform, not manual creation

---

## Tag Naming Conventions

### Approved Tag Keys

| Tag Key | Format | Example | Notes |
|---------|--------|---------|-------|
| Project | PascalCase | MediaCMS | Project identifier |
| Environment | PascalCase | Production | Environment name |
| Owner | PascalCase | Mohsen Minai | Full name |
| ManagedBy | PascalCase | Terraform | Management tool |
| CostCenter | PascalCase | MediaCMS-Infrastructure | Hyphen-separated |
| Compliance | PascalCase | CMPE-281-FinalProject | Hyphen-separated |
| Name | PascalCase | mohsen-mediacms-vpc | Resource-specific |

### Prohibited Tag Keys

❌ Do NOT use:
- `name` (use `Name` instead)
- `env` (use `Environment`)
- `project` (use `Project`)
- Any keys with spaces
- Any keys with special characters except hyphen and underscore

---

## Reporting

### Monthly Tag Compliance Report

```bash
#!/bin/bash
# generate-tag-report.sh

echo "MediaCMS Tag Compliance Report"
echo "Date: $(date)"
echo ""

# Count total resources
total=$(aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=mediacms \
  --query 'length(ResourceTagMappingList)' \
  --output text)

echo "Total Resources: $total"

# Count by environment
for env in dev staging production; do
  count=$(aws resourcegroupstaggingapi get-resources \
    --tag-filters \
      Key=Project,Values=mediacms \
      Key=Environment,Values=$env \
    --query 'length(ResourceTagMappingList)' \
    --output text)
  echo "Environment $env: $count resources"
done
```

---

## Future Enhancements

### 1. Additional Tags

Consider adding:
- `BackupPolicy: Daily/Weekly/None`
- `DataClassification: Public/Internal/Confidential`
- `DisasterRecovery: Critical/Important/Standard`
- `EndDate: 2025-12-31` (for temporary resources)

### 2. Tag-Based IAM Policies

Restrict access by environment:

```hcl
data "aws_iam_policy_document" "dev_only" {
  statement {
    effect = "Allow"
    actions = ["*"]
    resources = ["*"]
    
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Environment"
      values   = ["dev"]
    }
  }
}
```

### 3. Automated Tag Cleanup

Lambda function to fix tag formatting:

```python
def standardize_tags(resource_arn, tags):
    """Ensure tags follow naming convention"""
    standardized = {}
    for key, value in tags.items():
        # Convert to PascalCase
        key = key.title().replace(' ', '')
        # Convert value to lowercase
        value = value.lower()
        standardized[key] = value
    return standardized
```

---

## Related Files

- Provider Config: `terraform/provider.tf` (lines 15-23)
- Variables: `terraform/variables.tf` (lines 13-22)
- All Module Files: Inherit tags automatically

---

**Last Updated:** December 9, 2024  
**Tag Policy Version:** 1.0  
**Status:** Enforced via Terraform provider default_tags
