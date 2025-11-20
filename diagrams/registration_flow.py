from diagrams import Diagram, Cluster, Edge
from diagrams.aws.network import ELB
from diagrams.aws.compute import Fargate
from diagrams.aws.database import RDS, ElastiCache
from diagrams.aws.integration import SNS
from diagrams.generic.blank import Blank

with Diagram("User Registration Flow - MediaCMS", show=False, direction="LR", filename="registration_flow"):
    
    with Cluster("User Actions"):
        user = Blank("User\nBrowser")
    
    with Cluster("Load Balancing"):
        alb = ELB("Application\nLoad Balancer")
    
    with Cluster("Application Layer"):
        ecs = Fargate("ECS Fargate\nContainer\n(MediaCMS)")
    
    with Cluster("Caching Layer"):
        redis = ElastiCache("Redis\nSession Cache\n24h TTL")
    
    with Cluster("Database Layer"):
        rds = RDS("PostgreSQL\nUsers Table\nTokens Table")
    
    with Cluster("Notification Service"):
        sns = SNS("SNS Topic\nEmail Service")
    
    # Registration Flow
    user >> Edge(label="1. POST /register\n{username, email, password}", color="blue") >> alb
    alb >> Edge(label="2. Route to\nhealthy task", color="blue") >> ecs
    
    ecs >> Edge(label="3. Check if\nemail exists", color="purple") >> rds
    rds >> Edge(label="4. No matching\nuser found", color="purple", style="dashed") >> ecs
    
    ecs >> Edge(label="5. Hash password\n& INSERT user", color="purple") >> rds
    rds >> Edge(label="6. User created\nID: 12345", color="purple", style="dashed") >> ecs
    
    ecs >> Edge(label="7. Generate\nverification token", color="purple") >> rds
    rds >> Edge(label="8. Token saved\nExpires: 24h", color="purple", style="dashed") >> ecs
    
    ecs >> Edge(label="9. Send welcome\nemail", color="orange") >> sns
    sns >> Edge(label="10. Email:\n'Verify account'", color="orange", style="dashed") >> user
    
    ecs >> Edge(label="11. Cache user\nsession", color="red") >> redis
    redis >> Edge(label="12. Session cached\nTTL: 24h", color="red", style="dashed") >> ecs
    
    ecs >> Edge(label="13. HTTP 201\nCreated", color="blue", style="dashed") >> alb
    alb >> Edge(label="14. Account\ncreated!", color="blue", style="dashed") >> user
    
    # Verification Flow
    user >> Edge(label="15. Click email\nverification link", color="green") >> alb
    alb >> Edge(label="16. Route\nverification", color="green") >> ecs
    
    ecs >> Edge(label="17. Validate\ntoken", color="purple") >> rds
    rds >> Edge(label="18. Token found\n& valid", color="purple", style="dashed") >> ecs
    
    ecs >> Edge(label="19. UPDATE user\nverified=true", color="purple") >> rds
    rds >> Edge(label="20. User\nverified", color="purple", style="dashed") >> ecs
    
    ecs >> Edge(label="21. Update\ncached user", color="red") >> redis
    redis >> Edge(label="22. Cache\nupdated", color="red", style="dashed") >> ecs
    
    ecs >> Edge(label="23. HTTP 200 OK\nRedirect /login", color="green", style="dashed") >> alb
    alb >> Edge(label="24. Email verified!\nLogin now", color="green", style="dashed") >> user
