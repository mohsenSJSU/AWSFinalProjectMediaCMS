# Network Segmentation - Defense in Depth

**Author:** Mohsen Minai  
**Date:** December 2025
**Project:** MediaCMS on AWS

---

## Architecture Overview

MediaCMS implements **defense in depth** through strict network segmentation across 3 Availability Zones.

---

## Network Topology

### VPC Structure
- **VPC CIDR:** 10.0.0.0/16
- **Availability Zones:** 3 (us-west-2a, us-west-2b, us-west-2c)
- **Subnets:** 6 total (3 public + 3 private)

Internet
   ↓
Internet Gateway (igw)
   ↓
┌─────────────────── PUBLIC SUBNETS ────────────────────┐
│ 10.0.1.0/24 (AZ-a)  10.0.2.0/24 (AZ-b)  10.0.3.0/24 (AZ-c) │
│                                                        │
│  - Application Load Balancer (internet-facing)        │
│  - NAT Gateways (3 - one per AZ)                      │
└────────────────────────────────────────────────────────┘
                         ↓
┌─────────────── PRIVATE SUBNETS ────────────────┐
│ 10.0.10.0/24 (AZ-a) 10.0.11.0/24 (AZ-b) 10.0.12.0/24 (AZ-c)│
│                                                        │
│  - ECS Fargate Tasks (no public IPs)                  │
│  - RDS PostgreSQL Multi-AZ                            │
│  - ElastiCache Redis Cluster                          │
└────────────────────────────────────────────────────────┘

---

## Security Group Matrix

### Principle: **Least Privilege Network Access**

| Resource | Ingress Port | Source | Justification |
|----------|--------------|--------|---------------|
| **ALB** | 80 | 0.0.0.0/0 | Public internet access |
| **ALB** | 443 | 0.0.0.0/0 | HTTPS (future SSL) |
| **ECS Tasks** | 80 | ALB SG only | ONLY ALB can reach containers |
| **RDS PostgreSQL** | 5432 | ECS SG only | ONLY ECS can reach database |
| **ElastiCache Redis** | 6379 | ECS SG only | ONLY ECS can reach cache |

### Network Isolation Rules
- ✅ **RDS accepts:** Port 5432 from ECS security group ONLY
- ✅ **Redis accepts:** Port 6379 from ECS security group ONLY  
- ✅ **ECS accepts:** Port 80 from ALB security group ONLY
- ✅ **ALB accepts:** Ports 80/443 from internet
- ❌ **No direct internet access** to ECS, RDS, or Redis

---

## Defense in Depth Layers

### Layer 1: Internet Gateway
- **Public access:** ONLY to ALB
- **No direct access:** To any application components

### Layer 2: Application Load Balancer
- **Acts as:** Single point of entry
- **Inspects:** All incoming HTTP/HTTPS traffic
- **Forwards to:** Private ECS tasks only

### Layer 3: Private Subnets
- **No public IPs:** ECS, RDS, Redis have no internet routes
- **Outbound only:** Via NAT Gateway for updates
- **Cannot be reached:** Directly from internet

### Layer 4: Security Groups (Stateful Firewall)
- **RDS:** Accepts ONLY from ECS security group on port 5432
- **Redis:** Accepts ONLY from ECS security group on port 6379
- **ECS:** Accepts ONLY from ALB security group on port 80

---

## Attack Surface Reduction

### ❌ BEFORE (Typical Insecure Setup)
```
Internet → RDS (public IP) ✗ Direct database access
Internet → Redis (public IP) ✗ Direct cache access
Internet → ECS (public IP) ✗ Direct container access
```

### ✅ AFTER (Our Secure Implementation)
```
Internet → ALB (public) → ECS (private) → RDS (private)
                                       → Redis (private)
```

**Attack surface:** Only ALB exposed to internet

---

## Security Group Implementation

### Code Reference: `terraform/main.tf`

#### ALB Security Group (Lines 14-46)
```hcl
resource "aws_security_group" "alb" {
  vpc_id = module.vpc.vpc_id
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Internet access
  }
}
```

#### ECS Security Group (Lines 48-72)
```hcl
resource "aws_security_group" "ecs" {
  ingress {
    from_port       = 80
    security_groups = [aws_security_group.alb.id]  # ONLY ALB
  }
}
```

#### RDS Security Group (Lines 74-98)
```hcl
resource "aws_security_group" "rds" {
  ingress {
    from_port       = 5432
    security_groups = [aws_security_group.ecs.id]  # ONLY ECS
  }
}
```

#### Redis Security Group (Lines 100-124)
```hcl
resource "aws_security_group" "redis" {
  ingress {
    from_port       = 6379
    security_groups = [aws_security_group.ecs.id]  # ONLY ECS
  }
}
```

---

## Network Flow Examples

### Example 1: User Watches Video
```
1. User browser → ALB (port 80) ✓ Allowed
2. ALB → ECS Task (port 80) ✓ Allowed (ALB → ECS SG rule)
3. ECS → RDS (port 5432) ✓ Allowed (ECS → RDS SG rule)
4. ECS → Redis (port 6379) ✓ Allowed (ECS → Redis SG rule)
5. ECS → S3 (port 443) ✓ Allowed (IAM role + egress)
```

### Example 2: Attacker Tries Direct Database Access
```
1. Attacker → RDS (port 5432) ✗ BLOCKED
   - RDS has NO public IP
   - RDS security group ONLY accepts from ECS SG
   - Request never reaches RDS
```

### Example 3: ECS Needs Package Updates
```
1. ECS → NAT Gateway (private subnet route)
2. NAT Gateway → Internet Gateway
3. Internet → Package repository ✓ Allowed (outbound only)
```

---

## High Availability

### Multi-AZ Deployment
- **ALB:** Spans all 3 AZs
- **ECS Tasks:** Distributed across all 3 AZs
- **RDS:** Multi-AZ with automatic failover
- **Redis:** 3-node cluster across AZs

### Failure Scenario
```
If AZ-a fails:
- ALB routes to ECS tasks in AZ-b and AZ-c ✓
- RDS automatically fails over to standby ✓
- Redis promotes replica to primary ✓
- NO user downtime
```

---

## Compliance

✅ **CIS AWS Foundations Benchmark**
- 4.1: No unused security groups
- 4.2: Default security group restricts all traffic
- 4.3: VPC security groups restrict ingress

✅ **AWS Well-Architected Framework**
- Security Pillar: Infrastructure protection
- Reliability Pillar: Multi-AZ architecture

✅ **PCI DSS** (if applicable)
- Requirement 1.2.1: Restrict inbound/outbound traffic
- Requirement 1.3.4: No direct public access to databases

---

## Verification Commands

### Check Security Group Rules
```bash
# RDS security group
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=mohsen-mediacms-rds-sg" \
  --query 'SecurityGroups[0].IpPermissions'

# Should show: Source = ECS security group ID only
```

### Check Subnet Routing
```bash
# Private subnet route table
aws ec2 describe-route-tables \
  --filters "Name=tag:Name,Values=mohsen-mediacms-private-rt-1"

# Should show: 0.0.0.0/0 → NAT Gateway (not Internet Gateway)
```

### Verify No Public IPs on ECS
```bash
aws ecs list-tasks --cluster mohsen-mediacms-cluster

aws ecs describe-tasks \
  --cluster mohsen-mediacms-cluster \
  --tasks <task-arn> \
  --query 'tasks[0].attachments[0].details'

# publicIPv4Address should be empty
```

---

## Terraform Implementation References

### VPC Module: `terraform/modules/vpc/vpc.tf`
- Lines 10-18: VPC with DNS enabled
- Lines 32-54: Public subnets (3 AZs)
- Lines 56-75: Private subnets (3 AZs)
- Lines 101-126: NAT Gateways (one per AZ)
- Lines 156-208: Private route tables (routed to NAT)

### Main Configuration: `terraform/main.tf`
- Lines 136-146: RDS in private subnets
- Lines 150-157: Redis in private subnets
- Lines 172-178: ECS in private subnets
- Lines 14-46: ALB security group (internet-facing)
- Lines 48-72: ECS security group (ALB access only)
- Lines 74-98: RDS security group (ECS access only)
- Lines 100-124: Redis security group (ECS access only)



## Security Posture Summary

| Component | Public IP | Internet Access | Access Method |
|-----------|-----------|-----------------|---------------|
| ALB | ✅ Yes | Inbound + Outbound | Direct |
| NAT Gateway | ✅ Yes | Outbound only | N/A |
| ECS Tasks | ❌ No | Via NAT only | Through ALB |
| RDS | ❌ No | Via NAT only | From ECS only |
| Redis | ❌ No | Via NAT only | From ECS only |
| S3 Bucket | ❌ No | Via IAM + NAT | From ECS only |

---

**Last Updated:** December 9, 2025  
**Verified:** All resources in correct network segments  
**Status:** Production-ready security posture

