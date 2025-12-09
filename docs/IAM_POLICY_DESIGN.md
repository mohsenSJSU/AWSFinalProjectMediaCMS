# IAM Policy Design - Principle of Least Privilege

**Author:** Mohsen Minai  
**Date:** December 2025  
**Project:** MediaCMS on AWS

---

## Overview

This document details the IAM permissions granted to the MediaCMS application and justifies each permission under the Principle of Least Privilege.

---

## IAM Role Architecture

MediaCMS uses **two separate IAM roles** to enforce separation of concerns:

### 1. ECS Execution Role (`ecs_execution_role`)
**Purpose:** Infrastructure management by AWS ECS service

**Permissions:**
- AWS Managed Policy: `AmazonECSTaskExecutionRolePolicy`

**Grants:**
- `ecr:GetAuthorizationToken` - Pull Docker images
- `ecr:BatchCheckLayerAvailability` - Verify image layers
- `ecr:GetDownloadUrlForLayer` - Download container images
- `ecr:BatchGetImage` - Pull container images
- `logs:CreateLogStream` - Create CloudWatch log streams
- `logs:PutLogEvents` - Write application logs

**Justification:** These are standard AWS ECS infrastructure permissions required for container orchestration. This role is used by the ECS service itself, NOT by the application code.

---

### 2. ECS Task Role (`ecs_task_role`)
**Purpose:** Application-level permissions for MediaCMS

**Permissions:** Custom policy (minimal S3 access)

---

## S3 Policy - Before vs After

### BEFORE (Overly Permissive)

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",    REMOVED
      "s3:ListBucket"
    ],
    "Resource": [
      "arn:aws:s3:::bucket-name",
      "arn:aws:s3:::bucket-name/*"
    ]
  }]
}
Issues:
• Allows deletion of any object
• No encryption enforcement
• Single broad statement
• Mixed bucket and object permissions

{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowListBucket",
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": ["arn:aws:s3:::bucket-name"]
    },
    {
      "Sid": "AllowReadWriteObjects",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject"
      ],
      "Resource": ["arn:aws:s3:::bucket-name/*"],
      "Condition": {
        "StringEquals": {
          "s3:x-amz-server-side-encryption": "AES256"
        }
      }
    }
  ]
}
Improvements:
• Removed s3:DeleteObject permission
• Enforces encryption on uploads
• Separate statements for clarity
• Explicit resource scoping

s3:ListBucket - Check if uploaded files exist, Video catalog, thumbnails
s3:PutObject - Upload videos, images, thumbnails, User uploads, transcoding
s3:GetObject - Stream/download media files, Video playback, downloads
s3:DeleteObject - Media deletion should be soft-delete in database, not physical S3 deletion. Prevents accidental data loss. (REMOVED)

### Security Enhancements

1. Encryption Enforcement
Condition = {
  StringEquals = {
    "s3:x-amz-server-side-encryption" = "AES256"
  }
}
• All uploads MUST use server-side encryption
• Unencrypted uploads will be denied
• Protects data at rest

2. Resource Scoping
Resource = [
  "arn:aws:s3:::bucket-name",      # Bucket operations
  "arn:aws:s3:::bucket-name/*"     # Object operations
]
• Bucket-level operations (ListBucket) scoped to bucket ARN
• Object-level operations (Get/Put) scoped to objects only
• Prevents access to other S3 buckets

3. Statement IDs (SIDs)
Sid = "AllowListBucket"

•Improves readability in AWS Console
•Easier to audit and understand
•Better CloudTrail logging