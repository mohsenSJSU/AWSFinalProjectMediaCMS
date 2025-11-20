from diagrams import Diagram, Cluster, Edge
from diagrams.aws.network import ELB
from diagrams.aws.compute import Fargate
from diagrams.aws.database import RDS, ElastiCache
from diagrams.aws.storage import S3
from diagrams.aws.integration import SNS
from diagrams.generic.blank import Blank

with Diagram("Watch & Share Video Flow - MediaCMS", show=False, direction="LR", filename="share_flow"):
    
    with Cluster("Users"):
        userA = Blank("User A\nVideo Owner")
        userB = Blank("User B\nRecipient")
    
    with Cluster("Load Balancing"):
        alb = ELB("Application\nLoad Balancer")
    
    with Cluster("Application Layer"):
        ecs = Fargate("ECS Fargate\nTask")
    
    with Cluster("Cache Layer"):
        redis = ElastiCache("Redis\nCache\n95% Hit Rate")
    
    with Cluster("Database Layer"):
        rds = RDS("PostgreSQL\nVideos\n& Shares")
    
    with Cluster("Storage"):
        s3 = S3("S3 Bucket\nVideo Files")
    
    with Cluster("Notifications"):
        sns = SNS("SNS Topic\nEmail Service")
    
    # Watch Video Flow (Cache Hit)
    userA >> Edge(label="1. GET /video/9876\nRequest video", color="blue") >> alb
    alb >> Edge(label="2. Route", color="blue") >> ecs
    
    ecs >> Edge(label="3. Check cache\nGET video:9876", color="red") >> redis
    redis >> Edge(label="4. Cache HIT! ⚡\n{metadata}\n5ms response", color="red", style="dashed") >> ecs
    
    ecs >> Edge(label="5. Generate\npre-signed URL\nExpires: 1 hour", color="orange") >> s3
    s3 >> Edge(label="6. Signed URL\nwith credentials", color="orange", style="dashed") >> ecs
    
    ecs >> Edge(label="7. Increment\nview counter", color="purple") >> rds
    rds >> Edge(label="8. Views: 1,234", color="purple", style="dashed") >> ecs
    
    ecs >> Edge(label="9. Update\ncache counter", color="red") >> redis
    
    ecs >> Edge(label="10. Return video\nmetadata & URL", color="blue", style="dashed") >> alb
    alb >> Edge(label="11. Video loads", color="blue", style="dashed") >> userA
    
    userA >> Edge(label="12. Stream video\n(Direct to S3)", color="orange") >> s3
    
    # Share Video Flow
    userA >> Edge(label="13. POST /share\n{video: 9876,\nto: userb@email}", color="green") >> alb
    alb >> Edge(label="14. Process share", color="green") >> ecs
    
    ecs >> Edge(label="15. Validate\nauth token", color="red") >> redis
    redis >> Edge(label="16. User A\nauthenticated", color="red", style="dashed") >> ecs
    
    ecs >> Edge(label="17. INSERT share\nrecord", color="purple") >> rds
    rds >> Edge(label="18. Share ID: 555\nCreated", color="purple", style="dashed") >> ecs
    
    ecs >> Edge(label="19. Check if\nUser B exists", color="purple") >> rds
    rds >> Edge(label="20. User B found\nID: 99999", color="purple", style="dashed") >> ecs
    
    ecs >> Edge(label="21. Create\nnotification", color="purple") >> rds
    
    ecs >> Edge(label="22. Publish\nreal-time alert", color="red") >> redis
    redis >> Edge(label="23. 🔔 Notification", color="red", style="dashed") >> userB
    
    ecs >> Edge(label="24. Send email\n'User A shared video'", color="brown") >> sns
    sns >> Edge(label="25. 📧 Email with\nvideo link", color="brown", style="dashed") >> userB
    
    ecs >> Edge(label="26. Update share\nstatus='sent'", color="purple") >> rds
    
    ecs >> Edge(label="27. Success\nresponse", color="green", style="dashed") >> alb
    alb >> Edge(label="28. Video shared!", color="green", style="dashed") >> userA
    
    # User B Opens Video
    userB >> Edge(label="29. Click email\nlink", color="blue") >> alb
    alb >> Edge(label="30. Track open", color="blue") >> ecs
    
    ecs >> Edge(label="31. Log share\nopened", color="purple") >> rds
    
    ecs >> Edge(label="32. Return video", color="blue", style="dashed") >> alb
    alb >> Edge(label="33. 🎬 Watch video\n'Shared by User A'", color="blue", style="dashed") >> userB
