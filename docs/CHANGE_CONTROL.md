# Change Control & Deployment Strategy

**Author:** Mohsen Minai  
**Date:** December 2024  
**Project:** MediaCMS on AWS

---

## Overview

This document defines the change control process and deployment strategy for the MediaCMS infrastructure. It ensures that infrastructure changes are reviewed, tested, and deployed safely across multiple environments.

---

## Environment Strategy

### Three-Tier Environment Model

| Environment | Purpose | Stability | Auto-Deploy | Approval Required |
|-------------|---------|-----------|-------------|-------------------|
| **Development** | Feature development, experimentation | Low | Yes (on merge to dev branch) | 1 reviewer |
| **Staging** | Pre-production testing, QA validation | Medium | No (manual trigger) | 2 reviewers |
| **Production** | Live customer-facing system | High | No (manual trigger) | 2 reviewers + manager |

---

## Environment Configurations

### Development Environment

**Purpose:** Rapid iteration and testing

**Configuration:**
```hcl
# terraform/environments/dev.tfvars
environment       = "dev"
ecs_desired_count = 1           # Single task
ecs_min_capacity  = 1
ecs_max_capacity  = 2
db_instance_class = "db.t3.small"  # Smaller instance
redis_node_type   = "cache.t3.micro"
alarm_email       = "dev-team@example.com"
```

**Characteristics:**
- Single AZ deployment (cost savings)
- Smaller instance sizes
- Relaxed auto-scaling limits
- Short backup retention (1 day)
- Can be torn down nightly to save costs

**Cost:** ~$120/month

---

### Staging Environment

**Purpose:** Production-like testing and validation

**Configuration:**
```hcl
# terraform/environments/staging.tfvars
environment       = "staging"
ecs_desired_count = 2
ecs_min_capacity  = 2
ecs_max_capacity  = 5
db_instance_class = "db.t3.medium"
redis_node_type   = "cache.t3.micro"
alarm_email       = "staging-alerts@example.com"
```

**Characteristics:**
- Multi-AZ deployment (same as production)
- Same instance sizes as production
- Production-like auto-scaling
- 3-day backup retention
- Load testing and performance validation

**Cost:** ~$300/month

---

### Production Environment

**Purpose:** Live customer-facing system

**Configuration:**
```hcl
# terraform/environments/production.tfvars
environment       = "production"
ecs_desired_count = 2
ecs_min_capacity  = 2
ecs_max_capacity  = 10
db_instance_class = "db.t3.medium"
redis_node_type   = "cache.t3.micro"
alarm_email       = "prod-alerts@example.com"
```

**Characteristics:**
- Multi-AZ deployment across 3 AZs
- Production-grade instance sizes
- Aggressive auto-scaling limits
- 7-day backup retention
- 24/7 monitoring and alerting

**Cost:** ~$366/month

---

## Change Control Process

### Step 1: Development

```
Developer creates feature branch
  ↓
Makes infrastructure changes
  ↓
Tests locally with terraform plan
  ↓
Commits to feature branch
  ↓
Opens Pull Request to 'dev' branch
```

**Requirements:**
- Terraform validate passes
- Terraform plan shows expected changes
- No hardcoded secrets
- All resources properly tagged
- Documentation updated

---

### Step 2: Code Review

```
Pull Request opened
  ↓
Automated checks run (GitHub Actions)
  - terraform fmt -check
  - terraform validate
  - tflint (Terraform linter)
  - checkov (security scanner)
  ↓
At least 1 reviewer approves
  ↓
Merge to 'dev' branch
```

**Review Checklist:**
- [ ] Terraform syntax is valid
- [ ] Changes follow least privilege principle
- [ ] No secrets in code
- [ ] Resources properly tagged
- [ ] Documentation updated
- [ ] Backward compatible (no breaking changes)

---

### Step 3: Deploy to Development

```
Merge to 'dev' branch triggers:
  ↓
GitHub Actions workflow runs
  ↓
terraform plan -var-file="environments/dev.tfvars"
  ↓
Auto-approve and apply to dev environment
  ↓
Smoke tests run
  ↓
Slack notification: "Dev deployed successfully"
```

**Automated Tests:**
- Application health check (HTTP 200)
- Database connectivity test
- S3 bucket accessibility
- Secrets Manager access

---

### Step 4: Promote to Staging

```
Manual trigger: Create PR from 'dev' to 'staging'
  ↓
2 reviewers must approve
  ↓
Merge to 'staging' branch
  ↓
GitHub Actions runs terraform plan
  ↓
Manual approval required in GitHub
  ↓
terraform apply -var-file="environments/staging.tfvars"
  ↓
Integration tests run (30 min)
  ↓
Load tests run (1 hour)
```

**Staging Tests:**
- Full integration test suite
- Load testing (simulated user traffic)
- Security scanning
- Backup/restore validation
- Failover testing

**Approval Required:**
- 2 senior engineers
- QA sign-off
- Must be during business hours

---

### Step 5: Production Deployment

```
Manual trigger: Create PR from 'staging' to 'main'
  ↓
2 reviewers + Engineering Manager approve
  ↓
Schedule deployment window (maintenance window)
  ↓
Create pre-deployment backup
  ↓
Merge to 'main' branch
  ↓
GitHub Actions runs terraform plan
  ↓
Engineering Manager approves in GitHub
  ↓
terraform apply -var-file="environments/production.tfvars"
  ↓
Monitor for 30 minutes
  ↓
Slack notification: "Production deployed"
```

**Production Requirements:**
- **Approval:** 2 senior engineers + 1 manager
- **Timing:** Only during maintenance windows (Saturday 2-4 AM PST)
- **Backup:** Full RDS snapshot before deployment
- **Rollback Plan:** Documented and tested
- **Monitoring:** Engineering on-call during deployment
- **Communication:** Email sent to all users 24h advance

---

## CI/CD Pipeline (GitHub Actions)

### Workflow File: `.github/workflows/terraform.yml`

```yaml
name: Terraform CI/CD

on:
  pull_request:
    branches: [dev, staging, main]
  push:
    branches: [dev, staging, main]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2
      
      - name: Terraform Format Check
        run: terraform fmt -check -recursive
      
      - name: Terraform Init
        run: terraform init
      
      - name: Terraform Validate
        run: terraform validate
      
      - name: Run tflint
        run: tflint
      
      - name: Run Checkov Security Scan
        run: checkov -d terraform/

  plan:
    needs: validate
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Terraform Plan (Dev)
        if: github.ref == 'refs/heads/dev'
        run: |
          terraform init
          terraform plan -var-file="environments/dev.tfvars"
      
      - name: Terraform Plan (Staging)
        if: github.ref == 'refs/heads/staging'
        run: |
          terraform init
          terraform plan -var-file="environments/staging.tfvars"
      
      - name: Terraform Plan (Production)
        if: github.ref == 'refs/heads/main'
        run: |
          terraform init
          terraform plan -var-file="environments/production.tfvars"

  deploy-dev:
    needs: plan
    if: github.ref == 'refs/heads/dev'
    runs-on: ubuntu-latest
    steps:
      - name: Terraform Apply (Auto)
        run: terraform apply -auto-approve -var-file="environments/dev.tfvars"

  deploy-staging:
    needs: plan
    if: github.ref == 'refs/heads/staging'
    runs-on: ubuntu-latest
    environment: staging  # Requires manual approval
    steps:
      - name: Terraform Apply
        run: terraform apply -var-file="environments/staging.tfvars"

  deploy-production:
    needs: plan
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production  # Requires manager approval
    steps:
      - name: Terraform Apply
        run: terraform apply -var-file="environments/production.tfvars"
```

---

## Branch Protection Rules

### Development Branch (`dev`)
- **Require:** 1 approving review
- **Require:** Status checks pass
- **Allow:** Force push (for rapid iteration)
- **Delete:** Branch after merge

### Staging Branch (`staging`)
- **Require:** 2 approving reviews
- **Require:** All status checks pass
- **Require:** Conversation resolution
- **Disallow:** Force push
- **Require:** Linear history

### Main Branch (`main` / Production)
- **Require:** 2 approving reviews + CODEOWNERS approval
- **Require:** All status checks pass
- **Require:** Signed commits
- **Disallow:** Force push
- **Disallow:** Deletions
- **Require:** Up-to-date with base branch

---

## Rollback Procedures

### Emergency Rollback

**Trigger:** Critical production issue detected

**Process:**
1. **Immediate:** Revert to previous Terraform state
   ```bash
   # Use Terraform state rollback
   terraform state pull > current_state.json
   terraform state push previous_state.json
   terraform apply
   ```

2. **Database:** Restore from latest snapshot
   ```bash
   aws rds restore-db-instance-from-db-snapshot \
     --db-instance-identifier mediacms-db-rollback \
     --db-snapshot-identifier mediacms-auto-snapshot-latest
   ```

3. **Verification:** Run health checks
4. **Communication:** Notify stakeholders
5. **Post-Mortem:** Root cause analysis within 24h

**Expected Rollback Time:** 15 minutes

---

### Planned Rollback

**Trigger:** Issues found during deployment monitoring

**Process:**
1. **Pause:** Stop deployment if in progress
2. **Assess:** Determine scope of impact
3. **Decision:** Rollback or hotfix?
4. **Execute:** Use git revert (preserves history)
   ```bash
   git revert HEAD
   git push origin main
   # Triggers automatic rollback deployment
   ```
5. **Monitor:** 30-minute observation period

---

## Monitoring During Deployments

### Pre-Deployment Checks
- [ ] All tests passing in staging
- [ ] Load tests completed successfully
- [ ] Security scans passed
- [ ] Backup completed
- [ ] On-call engineer assigned
- [ ] Communication sent

### During Deployment
- [ ] Monitor CloudWatch metrics every 5 minutes
- [ ] Watch error rates in logs
- [ ] Check ALB target health
- [ ] Monitor ECS task status
- [ ] Track RDS connections
- [ ] Verify Secrets Manager access

### Post-Deployment Checks
- [ ] All services healthy (30 min)
- [ ] No increase in error rates
- [ ] Response times within SLA
- [ ] User testing successful
- [ ] Smoke tests passed
- [ ] Rollback plan verified

---

## Disaster Recovery

### Recovery Time Objective (RTO)
- **Dev:** 4 hours
- **Staging:** 2 hours  
- **Production:** 30 minutes

### Recovery Point Objective (RPO)
- **Dev:** 24 hours (daily backups)
- **Staging:** 6 hours
- **Production:** 5 minutes (continuous RDS snapshots)

### DR Procedures

**Complete Infrastructure Loss:**
1. Provision new AWS account/region
2. Run `terraform apply` with backed-up state
3. Restore RDS from latest snapshot
4. Restore Redis from latest backup
5. Point DNS to new infrastructure
6. Verify all services operational

**Estimated Recovery Time:** 1 hour

---

## Security Controls

### Secrets Management
- ✅ No secrets in git repository
- ✅ Terraform variables encrypted in CI/CD
- ✅ AWS Secrets Manager for application secrets
- ✅ IAM roles (no long-term credentials)

### Access Control
- ✅ MFA required for AWS console access
- ✅ GitHub branch protection
- ✅ CODEOWNERS file enforced
- ✅ Audit logs enabled (CloudTrail)

### Compliance
- ✅ All changes tracked in git
- ✅ Approval chain documented
- ✅ Deployment logs retained
- ✅ Security scanning automated

---

## Communication Plan

### Planned Deployments

**Timeline:**
- **T-48h:** Announcement in team Slack
- **T-24h:** Email to all users (if user-facing changes)
- **T-2h:** Final go/no-go decision
- **T-0:** Deployment begins
- **T+30m:** Success notification or rollback initiated

**Channels:**
- Slack: `#infrastructure-deploys`
- Email: All users (for production)
- Status Page: status.mediacms.io

---

### Emergency Changes

**Criteria for Emergency:**
- Security vulnerability (CVE)
- Production outage
- Data loss risk
- Compliance violation

**Process:**
- Skip staging (if critical)
- Requires VP Engineering approval
- Post-deployment review within 24h
- Retrospective within 1 week

---

## Metrics & KPIs

### Deployment Metrics
- **Deployment Frequency:** Weekly (dev), Bi-weekly (staging), Monthly (prod)
- **Lead Time:** < 2 days (feature to production)
- **Mean Time to Recovery (MTTR):** < 15 minutes
- **Change Failure Rate:** < 5%

### Quality Metrics
- **Test Coverage:** > 80%
- **Security Scan Pass Rate:** 100%
- **Rollback Rate:** < 2%
- **Incident Rate:** < 1 per month

---

## Terraform Workspaces (Alternative Strategy)

Instead of branches, use Terraform workspaces:

```bash
# Create workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace new production

# Deploy to specific environment
terraform workspace select dev
terraform apply -var-file="environments/dev.tfvars"

terraform workspace select production
terraform apply -var-file="environments/production.tfvars"
```

**Benefits:**
- Single branch (main)
- Isolated state files per environment
- Easier to manage
- Less merge conflicts

---

## Future Enhancements

### 1. Blue/Green Deployments
- Maintain two identical production environments
- Switch traffic between them
- Zero-downtime deployments

### 2. Canary Releases
- Deploy to 10% of users first
- Monitor metrics for 1 hour
- Gradually increase to 100%

### 3. Automated Rollback
- Detect anomalies automatically
- Auto-rollback if error rate > 1%
- Alert on-call engineer

### 4. Infrastructure Testing
- Terratest for automated testing
- Compliance-as-code (OPA policies)
- Cost estimation in PR comments

---

## Related Documentation

- IAM Policy Design: `docs/IAM_POLICY_DESIGN.md`
- Network Segmentation: `docs/NETWORK_SEGMENTATION.md`
- Secrets Management: `docs/SECRETS_MANAGEMENT.md`
- Resource Tagging: `docs/RESOURCE_TAGGING.md`

---

**Last Updated:** December 9, 2024  
**Change Control Version:** 1.0  
**Status:** Ready for implementation
