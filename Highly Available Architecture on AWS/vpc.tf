resource "aws_vpc" "medicare-vpc" {
  cidr_block            = var.vpcciderblock
  enable_dns_hostnames  = true
  enable_dns_support    = true

  tags = {
    Name = "${var.project}-vpc"
  }
}

##################################
# Subnets
##################################

resource "aws_subnet" "public_app_subnet_az1" {
  vpc_id            = aws_vpc.medicare-vpc.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "${var.region}a"

  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project} Public App AZ1"
  }
}

resource "aws_subnet" "public_app_subnet_az2" {
  vpc_id            = aws_vpc.medicare-vpc.id
  cidr_block        = "10.1.3.0/24"
  availability_zone = "${var.region}b"

  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project} Public App AZ2"
  }
}

resource "aws_subnet" "private_app_subnet_az1" {
  vpc_id            = aws_vpc.medicare-vpc.id
  cidr_block        = "10.1.2.0/24"
  availability_zone = "${var.region}a"

  tags = {
    Name = "${var.project} Private App AZ1"
  }
}

resource "aws_subnet" "private_app_subnet_az2" {
  vpc_id            = aws_vpc.medicare-vpc.id
  cidr_block        = "10.1.4.0/24"
  availability_zone = "${var.region}b"

  tags = {
    Name = "${var.project} Private App AZ2"
  }
}

resource "aws_subnet" "private_data_subnet_az1" {
  vpc_id            = aws_vpc.medicare-vpc.id
  cidr_block        = "10.1.5.0/24"
  availability_zone = "${var.region}a"

  tags = {
    Name = "${var.project} Private Data AZ1"
  }
}

resource "aws_subnet" "private_data_subnet_az2" {
  vpc_id            = aws_vpc.medicare-vpc.id
  cidr_block        = "10.1.6.0/24"
  availability_zone = "${var.region}b"

  tags = {
    Name = "${var.project} Private Data AZ2"
  }
}

##################################
# Route Table + Associations
##################################

resource "aws_route_table" "medicare-public-rt" {
  vpc_id = aws_vpc.medicare-vpc.id

  tags = {
    Name = "${var.project} Public RT"
  }
}

resource "aws_route" "public-route" {
  route_table_id          = aws_route_table.medicare-public-rt.id
  destination_cidr_block  = "0.0.0.0/0"
  gateway_id              = aws_internet_gateway.medicare-igw.id
}

resource "aws_route_table" "medicare-private-rt" {
  vpc_id = aws_vpc.medicare-vpc.id

  tags = {
    Name = "${var.project} Private RT"
  }
}

resource "aws_route" "private-route" {
  route_table_id          = aws_route_table.medicare-private-rt.id
  destination_cidr_block  = "0.0.0.0/0"
  gateway_id              = aws_nat_gateway.medicare-ngw.id
}

resource "aws_route_table_association" "public-app-rt-az1" {
  subnet_id       = aws_subnet.public_app_subnet_az1.id
  route_table_id  = aws_route_table.medicare-public-rt.id
}

resource "aws_route_table_association" "public-app-rt-az2" {
  subnet_id       = aws_subnet.public_app_subnet_az2.id
  route_table_id  = aws_route_table.medicare-public-rt.id
}

resource "aws_route_table_association" "private-app-rt-az1" {
  subnet_id       = aws_subnet.private_app_subnet_az1.id
  route_table_id  = aws_route_table.medicare-private-rt.id
}

resource "aws_route_table_association" "private-app-rt-az2" {
  subnet_id       = aws_subnet.private_app_subnet_az2.id
  route_table_id  = aws_route_table.medicare-private-rt.id
}

resource "aws_route_table_association" "private-data-rt-az1" {
  subnet_id       = aws_subnet.private_data_subnet_az1.id
  route_table_id  = aws_route_table.medicare-private-rt.id
}

resource "aws_route_table_association" "private-data-rt-az2" {
  subnet_id       = aws_subnet.private_data_subnet_az2.id
  route_table_id  = aws_route_table.medicare-private-rt.id
}

##################################
# IGW + EIP + NGW
##################################

resource "aws_internet_gateway" "medicare-igw" {
  vpc_id        = aws_vpc.medicare-vpc.id

  tags = {
    Name        = "${var.project}-igw"
  }
}

resource "aws_eip" "medicare-eip" {
  domain        = "vpc"
  depends_on    = [aws_internet_gateway.medicare-igw]

  tags = {
    Name        = "${var.project}-eip"
  }
}

resource "aws_nat_gateway" "medicare-ngw" {
  allocation_id       = aws_eip.medicare-eip.id
  subnet_id           = aws_subnet.public_app_subnet_az1.id
  depends_on          = [aws_eip.medicare-eip]

  tags = {
    Name              = "${var.project}-ngw"
  }
}

##################################
# Security Groups
##################################

resource "aws_security_group" "medicare-alb-sg" {
  name                = "medicare-alb-sg"
  description         = "Allow inbound HTTP/HTTPS from Internet"
  vpc_id              = aws_vpc.medicare-vpc.id

  ingress {
    description       = "HTTP from anywhere"
    from_port         = 80
    to_port           = 80
    protocol          = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
  }

  ingress {
    description       = "HTTPS from anywhere"
    from_port         = 443
    to_port           = 443
    protocol          = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
  }

  egress {
    from_port         = 0
    to_port           = 0
    protocol          = "-1"
    cidr_blocks       = ["0.0.0.0/0"]
  }

  tags = {
    Name              = "${var.project}-alb-sg"
  }
}

resource "aws_security_group" "medicare-app-sg" {
  name                = "medicare-app-sg"
  description         = "Allow HTTP traffic from ALB only"
  vpc_id              = aws_vpc.medicare-vpc.id

  ingress {
    from_port         = 80
    to_port           = 80
    protocol          = "tcp"
    security_groups   = [aws_security_group.medicare-alb-sg.id]
  }

  ingress {
    from_port         = 443
    to_port           = 443
    protocol          = "tcp"
    security_groups   = [aws_security_group.medicare-alb-sg.id]
  }

  egress {
    from_port         = 0
    to_port           = 0
    protocol          = "-1"
    cidr_blocks       = ["0.0.0.0/0"]
  }

  tags = {
    Name              = "${var.project}-app-sg"
  }
}

resource "aws_security_group" "medicare-rds-sg" {
  name        = "medicare-rds-sg"
  description = "Allow MySQL access from app servers"
  vpc_id      = aws_vpc.medicare-vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.medicare-app-sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-rds-sg"
  }
}

resource "aws_security_group" "medical_efs_sg" {
  name        = "${var.project}-efs-sg"
  description = "Allow NFS access from app servers"
  vpc_id      = aws_vpc.medicare-vpc.id

  ingress {
    description     = "NFS from app servers"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.medicare-app-sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-efs-sg"
  }
}

##################################
# ASG
##################################

resource "aws_launch_template" "medicare-launch-template" {
  name                      = "${var.project}-launch-template"
  description               = "app-template"
  image_id                  = var.ami_id
  instance_type             = var.instance_type
  key_name                  = var.key_name

  vpc_security_group_ids    = [aws_security_group.medicare-app-sg.id]

  user_data = base64encode(<<-EOT
    #!/bin/bash
    yum update -y
    yum install -y httpd git

    # Start Apache and enable it on boot
    systemctl start httpd
    systemctl enable httpd

    # Mount EFS first
    mkdir -p /var/www/html
    mount -t efs ${aws_efs_file_system.medicare-efs.id}:/ /var/www/html
    echo "${aws_efs_file_system.medicare-efs.id}:/ /var/www/html efs defaults,_netdev 0 0" >> /etc/fstab

    # Clone the full repo
    git clone https://github.com/techwithlucy/ztc-projects.git /tmp/fullrepo

    # Copy only the MedicalWebsite-master folder to Apache's web root
    cp -r /tmp/fullrepo/projects/solutions-architect-projects/project-2/MedicalWebsite-master/* /var/www/html

    # Set DB environment variables
    echo "export DB_HOST=${aws_db_instance.medicare-rds.address}" >> /etc/profile.d/db_env.sh
    echo "export DB_PORT=${var.db_port}" >> /etc/profile.d/db_env.sh
    echo "export DB_USER=${var.db_username}" >> /etc/profile.d/db_env.sh
    echo "export DB_PASSWORD=${var.db_password}" >> /etc/profile.d/db_env.sh
    echo "export DB_NAME=${aws_db_instance.medicare-rds.identifier}" >> /etc/profile.d/db_env.sh

    # Restart Apache to serve the new content
    systemctl restart httpd
  EOT
  )
}

resource "aws_autoscaling_group" "medicare-asg" {
  name                      = "${var.project}-asg"

  min_size                  = 1
  desired_capacity          = 2
  max_size                  = 3

  launch_template {
    id = aws_launch_template.medicare-launch-template.id
    version = "1"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 300

  target_group_arns = [
    aws_lb_target_group.medicare-alb-tg.arn
  ]

  vpc_zone_identifier = [
    aws_subnet.private_app_subnet_az1.id,
    aws_subnet.private_app_subnet_az2.id
  ]

  tag {
    key                 = "Name"
    value               = "${var.project}-instance"
    propagate_at_launch = true
  }
}

##################################
# ALB + Target Group
##################################

resource "aws_lb" "medicare-alb" {
  name                  = "${var.project}-alb"
  internal              = false
  load_balancer_type    = "application"
  
  security_groups       = [aws_security_group.medicare-alb-sg.id]
  subnets = [
    aws_subnet.public_app_subnet_az1.id,
    aws_subnet.public_app_subnet_az2.id
  ]
  enable_deletion_protection = false

  tags = {
    Name = "${var.project}-alb"
  }
}

resource "aws_lb_target_group" "medicare-alb-tg" {
  name = "${var.project}-alb-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.medicare-vpc.id

  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/"
    interval            = 30 
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project}-tg"
  }
}

resource "aws_lb_listener" "medicare-alb-listener" {
  load_balancer_arn   = aws_lb.medicare-alb.arn
  port                = 80
  protocol            = "HTTP"

  default_action {
    type              = "forward"
    target_group_arn  = aws_lb_target_group.medicare-alb-tg.arn
  }
}

# ------------------------------
# RDS Subnet Group
# ------------------------------

resource "aws_db_subnet_group" "medicare-rds" {
  name          = "${var.project}-subnet-group"
  subnet_ids    = [
    aws_subnet.private_data_subnet_az1.id,
    aws_subnet.private_data_subnet_az2.id
  ]
  tags = {
    Name        = "${var.project}-db-subnet-group"
  }
}

# ------------------------------
# RDS Database
# ------------------------------

resource "aws_db_instance" "medicare-rds" {
  identifier              = "${var.project}-db"

  engine                  = var.db_engine
  engine_version          = var.engine_version

  instance_class          = var.instance_class

  storage_type            = var.storage_type
  allocated_storage       = var.allocated_storage
  max_allocated_storage   = var.max_allocated_storage

  username                = var.db_username
  password                = var.db_password
  port                    = var.db_port

  db_subnet_group_name    = aws_db_subnet_group.medicare-rds.id
  vpc_security_group_ids  = [aws_security_group.medicare-rds-sg.id]

  publicly_accessible     = false
  multi_az                = true
  backup_retention_period = 7
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = {
   Name = "${var.project}-database"
  }
}

##################################
# Route 53
##################################

resource "aws_route53_zone" "medicare-hosted-zone" {
  name      = var.route53_domain
  comment   = "Public hosted zone for Medicare app"
  

  tags = {
    Name    = "${var.project}-hosted-zone"
    Project = var.project
  }
}

resource "aws_route53_health_check" "medicare-alb-health-check" {
  fqdn              = aws_lb.medicare-alb.dns_name
  type              = "HTTP"
  port              = 80
  resource_path     = "/"

  request_interval  = 30
  failure_threshold = 3

  tags = {
    Name            = "${var.project}-alb-health-check"
  }
}

##################################
# Route 53 Record
##################################

resource "aws_route53_record" "www_primary" {
  zone_id           = aws_route53_zone.medicare-hosted-zone.id
  name              = var.route53_domain
  type              = "A"

  set_identifier    = "failover-primary-record"

  failover_routing_policy {
    type            = "PRIMARY"
  }

  alias {
    name                    = aws_lb.medicare-alb.dns_name
    zone_id                 = aws_lb.medicare-alb.zone_id
    evaluate_target_health  = true
  }
  health_check_id           = aws_route53_health_check.medicare-alb-health-check.id
}

resource "aws_route53_record" "www_secondary" {
  zone_id           = aws_route53_zone.medicare-hosted-zone.id
  name              = "backup.${var.route53_domain}"
  type              = "CNAME"

  set_identifier    = "failover-secondary-record"

  failover_routing_policy {
    type            = "SECONDARY"
  }

  ttl = 60

  records           = [aws_s3_bucket.medicare_failover.website_endpoint]
}

##################################
# Route 53 Failover S3 Bucket
##################################

resource "aws_s3_bucket" "medicare_failover" {
  bucket            = "${var.project}-failover-site-km"
  force_destroy     = true

  tags = {
    Name            = "${var.project}-failover-site-km"
    Project         = var.project
  }
}

resource "aws_s3_bucket_public_access_block" "medicare-bucket-public" {
  bucket                  = aws_s3_bucket.medicare_failover.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "medicare_failover-static-site" {
  bucket = aws_s3_bucket.medicare_failover.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_object" "medicare_failover_index" {
  bucket        = aws_s3_bucket.medicare_failover.id
  key           = "index.html"
  source        = "index.html"
  content_type  = "text/html"
}

resource "aws_s3_bucket_policy" "medicare_failover" {
  bucket = aws_s3_bucket.medicare_failover.id

  depends_on = [
    aws_s3_bucket_public_access_block.medicare-bucket-public
  ]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.medicare_failover.arn}/*"
      }
    ]
  })
}

##################################
# EFS File System
##################################

resource "aws_efs_file_system" "medicare-efs" {
  creation_token = "${var.project}-efs"
  performance_mode = "generalPurpose"

  tags = {
    Name = "${var.project}-efs"
  }
}

resource "aws_efs_mount_target" "efs_az1" {
  file_system_id  = aws_efs_file_system.medicare-efs.id
  subnet_id       = aws_subnet.private_app_subnet_az1.id
  security_groups = [aws_security_group.medical_efs_sg.id]
}

resource "aws_efs_mount_target" "efs_az2" {
  file_system_id  = aws_efs_file_system.medicare-efs.id
  subnet_id       = aws_subnet.private_app_subnet_az2.id
  security_groups = [aws_security_group.medical_efs_sg.id]
}