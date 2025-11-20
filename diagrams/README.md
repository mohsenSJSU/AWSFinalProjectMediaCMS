# MediaCMS Architecture Diagrams

**Generated with Official AWS Icons**  
**Student:** Mohsen Minai  
**Project:** AWS Cloud Computing Final Project

---

## 📊 Generated Diagrams

All diagrams use **official AWS service icons** from the Python Diagrams library.

### **1. Infrastructure Diagram** - `mediacms_infrastructure.png`
- Shows complete AWS architecture
- Multi-AZ deployment across 3 Availability Zones
- Public/Private subnet separation
- All AWS services with official icons
- Data flow connections

**Components:**
- Internet Gateway
- Application Load Balancer
- ECS Fargate Cluster (Auto-Scaling 2-10 tasks)
- RDS PostgreSQL Multi-AZ
- ElastiCache Redis
- S3 Media Bucket
- NAT Gateways (3)
- CloudWatch Monitoring
- SNS Alerts

---

### **2. User Registration Flow** - `registration_flow.png`
- Complete user signup process
- Email verification workflow
- Database and cache interactions
- 24-step detailed sequence

**Flow:**
1. User submits registration form
2. Password hashing with bcrypt
3. Database record creation
4. Verification token generation
5. Welcome email via SNS
6. Session caching in Redis
7. Email verification process
8. Account activation

---

### **3. Video Upload Flow** - `upload_flow.png`
- Full video upload process
- Multipart upload to S3
- Metadata extraction and storage
- Auto-scaling trigger demonstration
- 18-step detailed sequence

**Flow:**
1. User uploads video file
2. Authentication via Redis
3. Database record creation (processing state)
4. Multipart upload to S3 (chunks)
5. Metadata extraction
6. Database update (ready state)
7. Cache metadata in Redis
8. CloudWatch metrics logging
9. Auto-scaling trigger (CPU > 70%)
10. Success response

---

### **4. Watch & Share Video Flow** - `share_flow.png`
- Video streaming process
- Redis cache hit demonstration
- Video sharing workflow
- Real-time notifications
- Email notifications via SNS
- 33-step detailed sequence

**Flow:**
1. User A requests video
2. Cache check (95% hit rate)
3. Pre-signed S3 URL generation
4. View counter increment
5. Video streaming from S3
6. Share with User B
7. Notification creation
8. Email sent via SNS
9. User B opens video
10. Share tracking

---

## 🔧 How These Were Generated

### **Technology Stack:**
- **Python Diagrams Library** (v0.24.4)
- **Graphviz** (v14.0.4)
- **Official AWS Icons** (built-in)

### **Generation Scripts:**
```bash
python3 infrastructure_diagram.py  # Creates infrastructure diagram
python3 registration_flow.py       # Creates registration flow
python3 upload_flow.py             # Creates upload flow
python3 share_flow.py              # Creates share flow
```

### **Dependencies:**
```bash
pip3 install diagrams
brew install graphviz
```

---

## 📐 Diagram Features

### **Color Coding:**
- 🔵 **Blue** - HTTP requests/responses
- 🟣 **Purple** - Database operations
- 🔴 **Red** - Cache operations
- 🟠 **Orange** - Storage operations (S3)
- 🟢 **Green** - Success/verification flows
- 🟤 **Brown** - Monitoring/logging
- ⚫ **Gray** - Outbound internet (dashed)

### **Line Styles:**
- **Solid lines** - Active requests
- **Dashed lines** - Responses/returns
- **Dotted lines** - Monitoring/metrics

---

## 📏 Image Specifications

| Diagram | Size | Resolution | Format |
|---------|------|------------|--------|
| Infrastructure | 256 KB | High | PNG |
| Registration | 217 KB | High | PNG |
| Upload | 236 KB | High | PNG |
| Share | 313 KB | High | PNG |

---

## 💡 Usage in Documents

### **For Microsoft Word/PowerPoint:**
1. Insert → Pictures
2. Select PNG file
3. Resize as needed
4. Add caption: "Figure X: [Diagram Name]"

### **For LaTeX:**
```latex
\includegraphics[width=\textwidth]{mediacms_infrastructure.png}
\caption{MediaCMS Infrastructure Architecture}
```

### **For Markdown:**
```markdown
![Infrastructure Diagram](mediacms_infrastructure.png)
```

---

## 🎨 Customization

To modify diagrams:

1. Edit the Python script (e.g., `infrastructure_diagram.py`)
2. Run the script again:
   ```bash
   python3 infrastructure_diagram.py
   ```
3. PNG will be regenerated

### **Example Modifications:**
- Change colors: `color="blue"`
- Change labels: `label="New Text"`
- Add components: Import new AWS icons
- Change layout: `direction="LR"` or `direction="TB"`

---

## 📚 AWS Icons Available

The diagrams library includes 200+ AWS service icons:

- **Compute:** EC2, ECS, Fargate, Lambda
- **Storage:** S3, EBS, EFS
- **Database:** RDS, DynamoDB, ElastiCache, Redshift
- **Networking:** VPC, ALB, NLB, CloudFront, Route53
- **Management:** CloudWatch, CloudTrail, Auto Scaling
- **Integration:** SNS, SQS, EventBridge
- **Security:** IAM, KMS, Secrets Manager

---

## 🔗 Resources

- [Python Diagrams Documentation](https://diagrams.mingrammer.com/)
- [AWS Architecture Icons](https://aws.amazon.com/architecture/icons/)
- [Graphviz Documentation](https://graphviz.org/documentation/)

---

## ✅ Quality Checks

All diagrams have been:
- ✅ Generated with official AWS icons
- ✅ Properly labeled with step numbers
- ✅ Color-coded for readability
- ✅ High-resolution PNG format
- ✅ Suitable for academic documents
- ✅ Professional presentation quality

---

## 📝 Notes

- Diagrams are version-controlled via Python scripts
- Easy to regenerate if specifications change
- Can be converted to SVG for vector graphics
- Can be exported to PDF for printing

---

**Generated:** November 18, 2024  
**Author:** Mohsen Minai  
**Course:** Cloud Computing Final Project  
**Institution:** San Jose State University
