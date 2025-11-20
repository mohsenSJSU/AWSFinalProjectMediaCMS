from diagrams import Diagram, Cluster, Edge
from diagrams.aws.network import ELB, InternetGateway, NATGateway, VPC, PublicSubnet, PrivateSubnet
from diagrams.aws.compute import ECS, Fargate
from diagrams.aws.database import RDS, ElastiCache
from diagrams.aws.storage import S3
from diagrams.aws.management import Cloudwatch
from diagrams.aws.integration import SNS
from diagrams.generic.blank import Blank

with Diagram("MediaCMS Infrastructure - Mohsen Minai AWS Final Project", show=False, direction="TB", filename="mediacms_infrastructure"):
    
    users = Blank("Internet\nUsers")
    
    with Cluster("AWS Cloud - us-west-2"):
        vpc_icon = VPC("VPC\n10.0.0.0/16")
        
        with Cluster("Public Subnets (3 AZs)"):
            pub_subnet = PublicSubnet("Public Subnets\n10.0.1-3.0/24")
            igw = InternetGateway("Internet\nGateway")
            alb = ELB("Application\nLoad Balancer\nPort 80/443")
            nat = NATGateway("NAT Gateways\n(x3 - one per AZ)")
        
        with Cluster("Private Subnets (3 AZs)"):
            priv_subnet = PrivateSubnet("Private Subnets\n10.0.11-13.0/24")
            
            with Cluster("ECS Fargate Cluster (Auto-Scaling 2-10)"):
                ecs = [
                    Fargate("ECS Task 1\n2 vCPU, 4GB RAM"),
                    Fargate("ECS Task 2\n2 vCPU, 4GB RAM"),
                    Fargate("Auto-Scaled\nTasks")
                ]
            
            with Cluster("Data Layer"):
                rds = RDS("PostgreSQL\nMulti-AZ\ndb.t3.medium")
                redis = ElastiCache("Redis Cache\ncache.t3.micro")
        
        s3 = S3("S3 Media Bucket\nVersioning Enabled")
        
        with Cluster("Monitoring & Alerting"):
            cw = Cloudwatch("CloudWatch\nLogs & Metrics")
            sns = SNS("SNS Topic\nEmail Alerts")
    
    # Connections - User to ALB
    users >> Edge(label="HTTPS", color="darkgreen") >> igw
    igw >> Edge(label="Route", color="darkgreen") >> alb
    
    # ALB to ECS Tasks
    alb >> Edge(label="Port 80", color="blue") >> ecs
    
    # ECS to Data Layer
    for task in ecs:
        task >> Edge(label="PostgreSQL\nPort 5432", color="purple") >> rds
        task >> Edge(label="Redis\nPort 6379", color="red") >> redis
        task >> Edge(label="Upload/Download\nMedia Files", color="orange") >> s3
        task >> Edge(label="Outbound\nInternet", style="dashed", color="gray") >> nat
    
    # NAT to Internet
    nat >> Edge(style="dashed", color="gray") >> igw
    
    # Monitoring
    ecs[0] >> Edge(label="Metrics", style="dotted", color="brown") >> cw
    rds >> Edge(style="dotted", color="brown") >> cw
    redis >> Edge(style="dotted", color="brown") >> cw
    alb >> Edge(style="dotted", color="brown") >> cw
    
    cw >> Edge(label="Trigger\nAlarms", color="red") >> sns
