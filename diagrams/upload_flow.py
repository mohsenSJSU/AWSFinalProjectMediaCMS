from diagrams import Diagram, Cluster, Edge
from diagrams.aws.network import ELB
from diagrams.aws.compute import Fargate
from diagrams.aws.database import RDS, ElastiCache
from diagrams.aws.storage import S3
from diagrams.aws.management import Cloudwatch, AutoScaling
from diagrams.generic.blank import Blank

with Diagram("Video Upload Flow with Auto-Scaling - MediaCMS", show=False, direction="LR", filename="upload_flow"):
    
    with Cluster("User"):
        user = Blank("User\nBrowser")
    
    with Cluster("Load Balancing"):
        alb = ELB("Application\nLoad Balancer")
    
    with Cluster("Application Layer"):
        ecs = Fargate("ECS Fargate\nTask\n2vCPU, 4GB RAM")
    
    with Cluster("Cache"):
        redis = ElastiCache("Redis\nSession\n& Metadata")
    
    with Cluster("Database"):
        rds = RDS("PostgreSQL\nVideo Metadata\n& Records")
    
    with Cluster("Storage"):
        s3 = S3("S3 Bucket\nMedia Files\nVersioning")
    
    with Cluster("Monitoring"):
        cw = Cloudwatch("CloudWatch\nMetrics\n& Logs")
        autoscale = AutoScaling("Auto Scaling\nPolicy\n2-10 tasks")
    
    # Upload Flow
    user >> Edge(label="1. POST /upload\nvideo.mp4 (500MB)\nAuth Token", color="blue") >> alb
    alb >> Edge(label="2. Route to\navailable task", color="blue") >> ecs
    
    ecs >> Edge(label="3. Validate\nJWT token", color="red") >> redis
    redis >> Edge(label="4. User authenticated\nID: 12345", color="red", style="dashed") >> ecs
    
    ecs >> Edge(label="5. Create video record\nstatus='processing'", color="purple") >> rds
    rds >> Edge(label="6. Video ID: 9876\nCreated", color="purple", style="dashed") >> ecs
    
    ecs >> Edge(label="7. Multipart upload\nChunks 1-10", color="orange") >> s3
    s3 >> Edge(label="8. Upload complete\nS3 URL returned", color="orange", style="dashed") >> ecs
    
    ecs >> Edge(label="9. Update metadata\nstatus='ready'", color="purple") >> rds
    rds >> Edge(label="10. Record updated", color="purple", style="dashed") >> ecs
    
    ecs >> Edge(label="11. Cache metadata\nTTL: 1 hour", color="red") >> redis
    redis >> Edge(label="12. Cached", color="red", style="dashed") >> ecs
    
    ecs >> Edge(label="13. Log metrics\nVideoUploaded: 1\nSize: 500MB", color="brown") >> cw
    cw >> Edge(label="14. Metric\nrecorded", color="brown", style="dashed") >> ecs
    
    # Auto-Scaling Flow
    cw >> Edge(label="15. CPU > 70%\nTrigger alarm", color="red") >> autoscale
    autoscale >> Edge(label="16. Launch\nnew task", color="green") >> ecs
    
    ecs >> Edge(label="17. HTTP 201\nCreated\n{video_id: 9876}", color="blue", style="dashed") >> alb
    alb >> Edge(label="18. Upload\nsuccessful!", color="blue", style="dashed") >> user
