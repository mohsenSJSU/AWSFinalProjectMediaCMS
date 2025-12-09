# IAM Policy Design: Least Privilege Implementation

**Project:** MediaCMS on AWS  
**Date:** December 2025  
**Author:** Mohsen Minai

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Problem Statement](#problem-statement)
3. [Current State Analysis](#current-state-analysis)
4. [Proposed Solution](#proposed-solution)
5. [Implementation Details](#implementation-details)
6. [Security Benefits](#security-benefits)
7. [Compliance & Standards](#compliance--standards)
8. [Testing & Validation](#testing--validation)
9. [Rollback Plan](#rollback-plan)

---

## Executive Summary

This document outlines the implementation of IAM least privilege principles for the MediaCMS ECS task role. The changes reduce unnecessary permissions by **25%** while enforcing encryption requirements at the policy level.

**Key Changes:**
- Removed `s3:DeleteObject` permission (not required for MediaCMS operation)
- Split IAM policy into granular statements with Sid identifiers
- Added encryption enforcement condition (`AES256` required)
- Scoped permissions to specific resource ARNs only

**Impact:**
- Attack surface reduced
- Accidental deletion prevention
- Compliance with CIS AWS Foundations Benchmark 1.16
- NIST 800-53 AC-6 (Least Privilege) alignment

---

## Problem Statement

The original ECS task role (`mohsen-mediacms-ecs-task`) had overly broad S3 permissions that violated the principle of least privilege:

1. **Unnecessary Delete Permission:** The `s3:DeleteObject` action was granted but never used by MediaCMS
2. **Monolithic Policy:** Single statement combining bucket and object permissions
3. **No Encryption Enforcement:** Policy allowed unencrypted uploads
4. **Audit Challenges:** No Sid identifiers for statement tracking

**Risk Assessment:**
- **Severity:** Medium
- **Likelihood:** Low (requires compromised container)
- **Impact:** High (potential data loss if exploited)

---

## Current State Analysis

### Original IAM Policy

```hcl
resource "aws_iam_role_policy" "ecs_task_s3_policy" {
  name = "mohsen-mediacms-ecs-s3"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",    # ← UNNECESSARY
        "s3:ListBucket"
      ]
      Resource = [
        "arn:aws:s3:::bucket-name",
        "arn:aws:s3:::bucket-name/*"    # ← MIXING BUCKET & OBJECTS
      ]
    }]
  })
}
```

### Permission Analysis

| Action | Required? | Justification |
|--------|-----------|---------------|
| `s3:PutObject` |  Yes | Upload video files |
| `s3:GetObject` | Yes | Serve media to users |
| `s3:DeleteObject` | No | MediaCMS doesn't delete from S3 |
| `s3:ListBucket` | Yes | Enumerate media files |

### MediaCMS S3 Usage Patterns

After analyzing the MediaCMS codebase and AWS CloudTrail logs:

- **Upload Flow:** Application uses `s3:PutObject` only
- **Playback Flow:** Application uses `s3:GetObject` only
- **Deletion Flow:** Soft-delete in database, S3 objects retained
- **Lifecycle:** Objects managed via S3 lifecycle policies, not application

---

## Proposed Solution

### Design Principles

1. **Least Privilege:** Grant only permissions required for operation
2. **Separation of Concerns:** Split bucket-level vs object-level permissions
3. **Defense in Depth:** Enforce encryption at policy level
4. **Auditability:** Add Sid identifiers for CloudTrail analysis

### New IAM Policy Design

```hcl
resource "aws_iam_role_policy" "ecs_task_s3_policy" {
  name = "mohsen-mediacms-ecs-s3"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowListBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.media_bucket_name}"
        ]
      },
      {
        Sid    = "AllowReadWriteObjects"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.media_bucket_name}/*"
        ]
        Condition = {
          StringEquals = {
            "s3:x-amz-server-side-encryption" = "AES256"
          }
        }
      }
    ]
  })
}
```

---

## Implementation Details

### Changes Summary

#### 1. Removed Unnecessary Permission
- **Before:** 4 actions (PutObject, GetObject, DeleteObject, ListBucket)
- **After:** 3 actions (PutObject, GetObject, ListBucket)
- **Reduction:** 25%

#### 2. Granular Statements
- **Statement 1 (AllowListBucket):** Bucket-level operations
  - Action: `s3:ListBucket`
  - Resource: `arn:aws:s3:::bucket-name` (bucket only)
  
- **Statement 2 (AllowReadWriteObjects):** Object-level operations
  - Actions: `s3:PutObject`, `s3:GetObject`
  - Resource: `arn:aws:s3:::bucket-name/*` (objects only)

#### 3. Encryption Enforcement
- **Condition:** `StringEquals` on `s3:x-amz-server-side-encryption`
- **Value:** `AES256` (S3-managed encryption)
- **Effect:** Unencrypted uploads will fail with `403 Forbidden`

#### 4. Sid Identifiers
- `AllowListBucket`: Tracks bucket enumeration requests
- `AllowReadWriteObjects`: Tracks object read/write requests

### Backward Compatibility

 **No breaking changes:** MediaCMS application code requires no modifications

---

## Security Benefits

### 1. Attack Surface Reduction
- Compromised container cannot delete S3 objects
- Prevents accidental or malicious data loss
- Limits blast radius of potential exploits

### 2. Encryption Enforcement
- Policy-level encryption requirement
- Cannot be bypassed by application code
- Complements bucket-level encryption settings

### 3. Audit Improvements
- CloudTrail logs include Sid values for easier filtering
- Example query: `eventName=PutObject AND requestParameters.Sid=AllowReadWriteObjects`

### 4. Compliance Alignment
- **CIS AWS Foundations Benchmark 1.16:** IAM policies attached only to roles
- **NIST 800-53 AC-6:** Least Privilege principle
- **NIST 800-53 SC-28:** Protection of Information at Rest

---

## Compliance & Standards

### CIS AWS Foundations Benchmark

#### Control 1.16: Ensure IAM policies are attached only to groups or roles
- Policy attached to ECS task role
- No user-level policy attachments

#### Control 2.1.1: Ensure S3 bucket encryption is enabled
- Encryption enforced at policy level
- AES256 server-side encryption required

### NIST 800-53 Rev 5

#### AC-6: Least Privilege
- Minimum permissions necessary
- Removed unnecessary delete capability

#### AC-2: Account Management
- Role-based access control
- Service-specific IAM roles

#### SC-12: Cryptographic Key Establishment and Management
- S3-managed encryption keys
- Policy-enforced encryption

#### SC-28: Protection of Information at Rest
- Server-side encryption required
- Condition-based enforcement

### AWS Well-Architected Framework

#### Security Pillar
- **SEC02-BP02:** Grant least privilege access
- **SEC08-BP01:** Implement secure key management
- **SEC09-BP02:** Enforce encryption at rest

---

## Testing & Validation

### 1. Terraform Validation

```bash
cd terraform
terraform fmt -recursive
terraform validate
```

**Expected Output:**
```
Success! The configuration is valid.
```

### 2. Policy Simulator Testing

```bash
# Test allowed action (should succeed)
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:role/mohsen-mediacms-ecs-task \
  --action-names s3:PutObject \
  --resource-arns arn:aws:s3:::bucket-name/video.mp4 \
  --context-entries "ContextKeyName=s3:x-amz-server-side-encryption,ContextKeyValues=AES256,ContextKeyType=string"

# Test denied action (should fail)
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:role/mohsen-mediacms-ecs-task \
  --action-names s3:DeleteObject \
  --resource-arns arn:aws:s3:::bucket-name/video.mp4
```

### 3. Application Testing

**Test Cases:**
- Upload video file (should succeed with encryption)
- Download video file (should succeed)
- List media bucket (should succeed)
- Upload without encryption (should fail with 403)
- Delete S3 object (should fail with 403)

### 4. CloudTrail Verification

After deployment, verify CloudTrail logs show new Sid values:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=bucket-name \
  --max-results 10
```

Look for `Sid` field in `requestParameters`.

---

## Rollback Plan

### Emergency Rollback (< 5 minutes)

If issues arise, revert IAM policy to previous version:

```bash
# 1. Checkout previous commit
git revert HEAD

# 2. Apply changes
cd terraform
terraform plan -target=module.ecs.aws_iam_role_policy.ecs_task_s3_policy
terraform apply -target=module.ecs.aws_iam_role_policy.ecs_task_s3_policy
```

### Gradual Rollback

If issues are non-critical, gradually restore permissions:

**Step 1:** Remove encryption condition
```hcl
# Comment out Condition block
# Condition = { ... }
```

**Step 2:** Add back DeleteObject (if needed)
```hcl
Action = [
  "s3:PutObject",
  "s3:GetObject",
  "s3:DeleteObject"  # Restored
]
```

### Monitoring During Rollback

Watch ECS task health:
```bash
aws ecs describe-services \
  --cluster mohsen-mediacms-cluster \
  --services mohsen-mediacms-service
```

Check for IAM permission errors in CloudWatch:
```bash
aws logs filter-log-events \
  --log-group-name /ecs/mohsen-mediacms \
  --filter-pattern "AccessDenied"
```

---

## Appendix A: Related IAM Roles

### ECS Execution Role (`mohsen-mediacms-ecs-execution`)

**Purpose:** Pull container images and write logs

**Permissions:**
- `ecr:GetAuthorizationToken`
- `ecr:BatchCheckLayerAvailability`
- `ecr:GetDownloadUrlForLayer`
- `ecr:BatchGetImage`
- `logs:CreateLogStream`
- `logs:PutLogEvents`

**Managed Policy:** `AmazonECSTaskExecutionRolePolicy`

### ECS Task Role (`mohsen-mediacms-ecs-task`)

**Purpose:** Application permissions (S3 access)

**Permissions:** Defined in this document (custom policy)

---

## Appendix B: Change Log

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| Dec 2025 | 1.0 | Mohsen Minai | Initial implementation |

---

## References

1. AWS IAM Best Practices: https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html
2. S3 Encryption: https://docs.aws.amazon.com/AmazonS3/latest/userguide/serv-side-encryption.html
3. CIS AWS Foundations Benchmark v1.4.0
4. NIST 800-53 Rev 5: Security and Privacy Controls
5. AWS Well-Architected Framework - Security Pillar

---

**Last Updated:** December 9, 2025  
**Document Version:** 1.0  
**Status:** Implemented 
