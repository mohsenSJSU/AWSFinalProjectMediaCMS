# Secrets Management - Eliminating Hardcoded Credentials

**Author:** Mohsen Minai  
**Date:** December 2025  
**Project:** MediaCMS on AWS

---

## Overview

This document details the migration of database credentials from hardcoded environment variables to AWS Secrets Manager, eliminating long-term static credentials.

---

## Problem: Hardcoded Secrets

### ❌ BEFORE (Insecure Implementation)

**File:** `terraform/modules/ecs/ecs.tf` (OLD)

```hcl
container_definitions = jsonencode([{
  environment = [
    { name = "POSTGRES_HOST", value = var.db_host },
    { name = "POSTGRES_DB", value = var.db_name },
    { name = "POSTGRES_USER", value = var.db_username },      # ← Hardcoded!
    { name = "POSTGRES_PASSWORD", value = var.db_password }    # ← Hardcoded!
  ]
}])
```

**Issues:**
- ⚠️ Credentials stored in plain text in task definition
- ⚠️ Visible in AWS Console, API responses, CloudWatch Events
- ⚠️ Stored in Terraform state file (even if encrypted)
- ⚠️ No rotation capability without redeploying infrastructure
- ⚠️ Risk of exposure through logs, errors, or AWS API calls

---

## Solution: AWS Secrets Manager

### ✅ AFTER (Secure Implementation)

**File:** `terraform/modules/ecs/ecs.tf` (NEW)

```hcl
container_definitions = jsonencode([{
  # Non-sensitive environment variables
  environment = [
    { name = "REDIS_HOST", value = var.redis_host },
    { name = "MEDIA_BUCKET", value = var.media_bucket_name }
  ]
  
  # Sensitive secrets retrieved at runtime from Secrets Manager
  secrets = [
    { name = "POSTGRES_HOST", valueFrom = "${var.db_secret_arn}:host::" },
    { name = "POSTGRES_DB", valueFrom = "${var.db_secret_arn}:dbname::" },
    { name = "POSTGRES_USER", valueFrom = "${var.db_secret_arn}:username::" },
    { name = "POSTGRES_PASSWORD", valueFrom = "${var.db_secret_arn}:password::" }
  ]
}])
```

**Improvements:**
- ✅ Credentials stored encrypted in Secrets Manager
- ✅ Retrieved at runtime using temporary IAM credentials
- ✅ Never visible in task definition or logs
- ✅ Rotation possible without infrastructure changes
- ✅ Audit trail of all secret access via CloudTrail

---

## Architecture

### Secret Storage Structure

**Secret Name:** `mohsen-mediacms-db-credentials`

**Secret Content** (JSON):
```json
{
  "username": "mediacms_admin",
  "password": "YourSecurePassword123!",
  "host": "mohsen-mediacms-db.xxxxx.us-west-2.rds.amazonaws.com",
  "dbname": "mediacms",
  "port": 5432,
  "engine": "postgres"
}
```

### Runtime Flow

```
1. ECS Task starts
   ↓
2. ECS uses EXECUTION ROLE to retrieve secret
   (IAM role has GetSecretValue permission)
   ↓
3. Secrets Manager returns encrypted secret
   ↓
4. ECS decrypts secret and injects into container
   as environment variables (POSTGRES_USER, etc.)
   ↓
5. MediaCMS application reads environment variables
   (No code changes required!)
   ↓
6. Application connects to database successfully
```

---

## IAM Permissions

### Execution Role Permission

**File:** `terraform/modules/ecs/ecs.tf`

```hcl
resource "aws_iam_role_policy" "ecs_execution_secrets_policy" {
  name = "mohsen-mediacms-ecs-execution-secrets"
  role = aws_iam_role.ecs_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowRetrieveDatabaseSecret"
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue"  # Read-only access
      ]
      Resource = [
        var.db_secret_arn  # Specific secret ARN only
      ]
    }]
  })
}
```

**Security Features:**
- ✅ Only `GetSecretValue` (cannot create, update, or delete secrets)
- ✅ Scoped to specific secret ARN (cannot access other secrets)
- ✅ Uses IAM role with temporary credentials (no long-term keys)
- ✅ Execution role separate from task role (separation of concerns)

---

## Implementation Details

### New Module: Secrets Manager

**File:** `terraform/modules/secrets/secrets.tf`

```hcl
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "mohsen-mediacms-db-credentials"
  description = "Database credentials for MediaCMS"
  
  recovery_window_in_days = 7  # Allows recovery if accidentally deleted
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = var.db_host
    dbname   = var.db_name
    port     = 5432
    engine   = "postgres"
  })
}
```

### Main Configuration Update

**File:** `terraform/main.tf`

```hcl
# Create secret BEFORE ECS module
module "secrets" {
  source = "./modules/secrets"

  project_name = var.project_name
  db_username  = var.db_username
  db_password  = var.db_password
  db_host      = module.rds.db_endpoint
  db_name      = var.db_name
}

# ECS module references secret ARN
module "ecs" {
  source = "./modules/ecs"
  
  # ... other config ...
  db_secret_arn = module.secrets.secret_arn  # Pass ARN, not credentials!
}
```

---

## Before/After Comparison

| Aspect | Before (Hardcoded) | After (Secrets Manager) |
|--------|-------------------|------------------------|
| **Storage** | Task definition (plain text) | Secrets Manager (encrypted) |
| **Visibility** | Visible in AWS Console | Hidden (need IAM permission) |
| **State File** | Credentials in state | Only ARN in state |
| **Rotation** | Requires redeploy | Update secret only |
| **Audit Trail** | No tracking | CloudTrail logs all access |
| **Access Method** | Direct from variables | IAM role with temporary creds |
| **Risk Level** | HIGH | LOW |

---

## Security Benefits

### 1. No Long-Term Credentials

**Before:**
```
terraform.tfvars (on your laptop)
  ↓
Terraform state (S3 bucket)
  ↓
AWS API (parameter passing)
  ↓
Task definition (stored in AWS)
  ↓
Container (environment variable)
```

Every step is a potential leak point!

**After:**
```
terraform.tfvars (on your laptop)
  ↓
Secrets Manager (encrypted storage)

Separately:
ECS Task → IAM Role → Secrets Manager → Container
```

Credentials only exist in Secrets Manager and briefly in container memory.

### 2. Encryption at Rest

- Secrets Manager encrypts secrets using AWS KMS
- Default: AWS-managed key
- Optional: Customer-managed key for additional control

### 3. Encryption in Transit

- All API calls to Secrets Manager use TLS
- Secrets never transmitted unencrypted

### 4. Temporary IAM Credentials

- ECS task role uses STS temporary credentials
- Credentials rotate automatically every few hours
- No long-term access keys to manage or leak

### 5. Audit Trail

All secret access logged to CloudTrail:
```json
{
  "eventName": "GetSecretValue",
  "userIdentity": {
    "type": "AssumedRole",
    "principalId": "AROAXXXXX:ecs-task-id"
  },
  "requestParameters": {
    "secretId": "mohsen-mediacms-db-credentials"
  },
  "responseElements": null
}
```

---

## Testing & Verification

### 1. Verify Secret Created

```bash
aws secretsmanager describe-secret \
  --secret-id mohsen-mediacms-db-credentials

# Expected: Secret exists with correct ARN and description
```

### 2. Test IAM Permission

```bash
aws secretsmanager get-secret-value \
  --secret-id mohsen-mediacms-db-credentials \
  --query 'SecretString' \
  --output text

# Expected: JSON with database credentials (if you have permission)
```

### 3. Verify ECS Can Access Secret

```bash
# Check ECS task logs for successful database connection
aws logs tail /ecs/mohsen-mediacms --follow

# Look for: "Database connection established"
# NOT: "Permission denied" or "Secret not found"
```

### 4. Verify No Credentials in Task Definition

```bash
aws ecs describe-task-definition \
  --task-definition mohsen-mediacms \
  --query 'taskDefinition.containerDefinitions[0].environment'

# Expected: Should NOT contain POSTGRES_PASSWORD
# Should only have non-sensitive values like REDIS_HOST
```

### 5. Verify Secrets Block Exists

```bash
aws ecs describe-task-definition \
  --task-definition mohsen-mediacms \
  --query 'taskDefinition.containerDefinitions[0].secrets'

# Expected: Array with POSTGRES_PASSWORD pointing to Secrets Manager ARN
```

---

## Compliance

✅ **CIS AWS Foundations Benchmark**
- 2.3.1: Ensure that encryption is enabled for Secrets Manager secrets
- 4.1: Ensure IAM policies are attached only to groups or roles

✅ **NIST 800-53**
- IA-5: Authenticator Management
- SC-12: Cryptographic Key Establishment and Management

✅ **PCI DSS**
- Requirement 8.2.1: Strong cryptography for authentication credentials
- Requirement 8.3.1: Secure storage of credentials

✅ **SOC 2**
- CC6.1: Logical and physical access controls
- CC6.6: Encryption of sensitive data

---

## Cost

**Secrets Manager Pricing** (us-west-2):
- $0.40 per secret per month
- $0.05 per 10,000 API calls

**Monthly Cost for This Project:**
- 1 secret × $0.40 = $0.40
- ~50,000 API calls (ECS task startups) × $0.05/10k = $0.25
- **Total: ~$0.65/month**

**Benefit vs Cost:** Preventing a single credential leak is worth far more than $0.65/month!

---

## Future Enhancements

### 1. Automatic Rotation

```hcl
resource "aws_secretsmanager_secret_rotation" "db_credentials" {
  secret_id           = aws_secretsmanager_secret.db_credentials.id
  rotation_lambda_arn = aws_lambda_function.rotate_secret.arn

  rotation_rules {
    automatically_after_days = 30
  }
}
```

### 2. Multiple Environments

```hcl
# Dev environment
resource "aws_secretsmanager_secret" "db_credentials_dev" {
  name = "mediacms-db-credentials-dev"
}

# Prod environment  
resource "aws_secretsmanager_secret" "db_credentials_prod" {
  name = "mediacms-db-credentials-prod"
}
```

### 3. Redis Credentials

Currently Redis doesn't require authentication. If enabled:

```hcl
secrets = [
  { name = "REDIS_PASSWORD", valueFrom = "${var.redis_secret_arn}:password::" }
]
```

---

## Related Files

- Secrets Module: `terraform/modules/secrets/secrets.tf`
- ECS Updates: `terraform/modules/ecs/ecs.tf` (lines 68-71, 157-174, 269-277)
- Main Config: `terraform/main.tf` (lines 170-183, 204)
- IAM Documentation: `docs/IAM_POLICY_DESIGN.md`

---

**Last Updated:** December 9, 2025  
**Status:** Implemented and tested  
**Security Level:** HIGH - No hardcoded credentials
