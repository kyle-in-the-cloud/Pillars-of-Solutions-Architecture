resource "aws_vpc" "securecart-vpc" {
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
  vpc_id            = aws_vpc.securecart-vpc.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "${var.region}a"

  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project} Public App AZ1"
  }
}

resource "aws_subnet" "public_app_subnet_az2" {
  vpc_id            = aws_vpc.securecart-vpc.id
  cidr_block        = "10.1.3.0/24"
  availability_zone = "${var.region}b"

  map_public_ip_on_launch = true

  tags = {
    Name = "Securecart Public App AZ2"
  }
}

resource "aws_subnet" "private_app_subnet_az1" {
  vpc_id            = aws_vpc.securecart-vpc.id
  cidr_block        = "10.1.2.0/24"
  availability_zone = "${var.region}a"

  tags = {
    Name = "Securecart Private App AZ1"
  }
}

resource "aws_subnet" "private_app_subnet_az2" {
  vpc_id            = aws_vpc.securecart-vpc.id
  cidr_block        = "10.1.4.0/24"
  availability_zone = "${var.region}b"

  tags = {
    Name = "Securecart Private App AZ2"
  }
}

##################################
# Route Table + Associations
##################################

resource "aws_route_table" "securecart-public-rt" {
  vpc_id = aws_vpc.securecart-vpc.id

  tags = {
    Name = "Securecart Public RT"
  }
}

resource "aws_route" "public-route" {
  route_table_id = aws_route_table.securecart-public-rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.securecart-igw.id
}

resource "aws_route_table" "securecart-private-rt" {
  vpc_id = aws_vpc.securecart-vpc.id

  tags = {
    Name = "Securecart Private RT"
  }
}

resource "aws_route" "private-route" {
  route_table_id = aws_route_table.securecart-private-rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_nat_gateway.securecart-ngw.id
}

resource "aws_route_table_association" "public-rt-az1" {
  subnet_id = aws_subnet.public_app_subnet_az1.id
  route_table_id = aws_route_table.securecart-public-rt.id
}

resource "aws_route_table_association" "public-rt-az2" {
  subnet_id = aws_subnet.public_app_subnet_az2.id
  route_table_id = aws_route_table.securecart-public-rt.id
}

resource "aws_route_table_association" "private-rt-az1" {
  subnet_id = aws_subnet.private_app_subnet_az1.id
  route_table_id = aws_route_table.securecart-private-rt.id
}

resource "aws_route_table_association" "private-rt-az2" {
  subnet_id = aws_subnet.private_app_subnet_az2.id
  route_table_id = aws_route_table.securecart-private-rt.id
}

##################################
# IGW + EIP + NGW
##################################

resource "aws_internet_gateway" "securecart-igw" {
  vpc_id        = aws_vpc.securecart-vpc.id

  tags = {
    Name        = "${var.project}-igw"
  }
}

resource "aws_eip" "securecart-eip" {
  domain        = "vpc"
  depends_on    = [aws_internet_gateway.securecart-igw]

  tags = {
    Name        = "${var.project}-eip"
  }
}

resource "aws_nat_gateway" "securecart-ngw" {
  allocation_id = aws_eip.securecart-eip.id
  subnet_id = aws_subnet.public_app_subnet_az1.id
  depends_on    = [aws_eip.securecart-eip]

  tags = {
    Name        = "${var.project}-ngw"
  }
}

##################################
# Security Groups
##################################

resource "aws_security_group" "securecart-alb-sg" {
  name                = "securecart-alb-sg"
  description         = "Allow inbound HTTP/HTTPS from Internet"
  vpc_id              = aws_vpc.securecart-vpc.id

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

resource "aws_security_group" "securecart-bastion-sg" {
  name                = "securecart-bastion-sg"
  description         = "Allow SSH traffic from My IP only"
  vpc_id              = aws_vpc.securecart-vpc.id

  ingress {
    from_port         = 22
    to_port           = 22
    protocol          = "tcp"
    cidr_blocks       = ["185.152.67.232/32"]
  }

  egress {
    from_port         = 0
    to_port           = 0
    protocol          = "-1"
    cidr_blocks       = ["0.0.0.0/0"]
  }

  tags = {
    Name              = "${var.project}-bastion-sg"
  }
}

resource "aws_security_group" "securecart-app-sg" {
  name                = "securecart-app-sg"
  description         = "Allow HTTP traffic from ALB only"
  vpc_id              = aws_vpc.securecart-vpc.id

  ingress {
    from_port         = 80
    to_port           = 80
    protocol          = "tcp"
    security_groups   = [aws_security_group.securecart-alb-sg.id]
  }

  ingress {
    from_port         = 22
    to_port           = 22
    protocol          = "tcp"
    security_groups   = [aws_security_group.securecart-bastion-sg.id]
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

resource "aws_security_group" "securecart-rds-sg" {
  name                = "securecart-rds-sg"
  description         = "Allow 3306 MySQL traffic from Securecart EC2 only"
  vpc_id              = aws_vpc.securecart-vpc.id

  ingress {
    from_port         = 3306
    to_port           = 3306
    protocol          = "tcp"
    security_groups   = [aws_security_group.securecart-app-sg.id]
  }

  egress {
    from_port         = 0
    to_port           = 0
    protocol          = "-1"
    cidr_blocks       = ["0.0.0.0/0"]
  }

  tags = {
    Name              = "${var.project}-rds-sg"
  }
}

##################################
# S3
##################################

resource "aws_s3_bucket" "securecart-bucket" {
  bucket              = "securecart-assets-km"
  force_destroy       = true
}

resource "aws_s3_bucket_public_access_block" "securecart-bucket-public" {
  bucket = aws_s3_bucket.securecart-bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

##################################
# EC2
##################################

resource "aws_instance" "securecart-ec2" {
  ami                 = "ami-0cae6d6fe6048ca2c"
  instance_type       = "t2.micro"

  vpc_security_group_ids = [aws_security_group.securecart-app-sg.id]
  subnet_id = aws_subnet.private_app_subnet_az1.id
  associate_public_ip_address = false

  tags = {
    Name = "${var.project}-App"
  }
}

resource "aws_instance" "securecart-bastion-ec2" {
  ami                 = "ami-0cae6d6fe6048ca2c"
  instance_type       = "t2.micro"

  vpc_security_group_ids = [aws_security_group.securecart-bastion-sg.id]
  subnet_id = aws_subnet.public_app_subnet_az1.id
  associate_public_ip_address = true

  tags = {
    Name = "${var.project}-Bastion"
  }
}

##################################
# ALB
##################################

resource "aws_lb" "securecart-alb" {
  name                  = "securecart-alb"
  internal              = false
  load_balancer_type    = "application"
  
  security_groups       = [aws_security_group.securecart-alb-sg.id]
  subnets = [
    aws_subnet.public_app_subnet_az1.id,
    aws_subnet.public_app_subnet_az2.id
  ]
  enable_deletion_protection = false

  tags = {
    Name = "${var.project}-alb"
  }
}

resource "aws_lb_target_group" "securecart-alb-tg" {
  name = "securecart-alb-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.securecart-vpc.id

  health_check {
    enabled = true
    interval = 30 
    path = "/"
    timeout = 5
    healthy_threshold = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project}-tg"
  }
}

resource "aws_lb_target_group_attachment" "securecart-tg-attach" {
  target_group_arn = aws_lb_target_group.securecart-alb-tg.arn
  target_id = aws_instance.securecart-ec2.id
  port = 80
}

resource "aws_lb_listener" "securecart-alb-listener" {
  load_balancer_arn = aws_lb.securecart-alb.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.securecart-alb-tg.arn
  }
}

# ------------------------------
# RDS Subnet Group
# ------------------------------

resource "aws_db_subnet_group" "securecart-rds" {
  name          = "${var.project}-subnet-group"
  subnet_ids    = [
    aws_subnet.private_app_subnet_az1.id,
    aws_subnet.private_app_subnet_az2.id
  ]
  tags = {
    Name        = "${var.project}-db-subnet-group"
  }
}

# ------------------------------
# RDS Database
# ------------------------------

resource "aws_db_instance" "securecart-rds" {
  identifier              = "${var.project}-db"

  engine                  = var.db_engine
  engine_version          = var.engine_version

  instance_class          = var.instance_class

  allocated_storage       = var.allocated_storage
  max_allocated_storage   = var.max_allocated_storage

  username                = var.db_username
  password                = var.db_password
  port                    = var.db_port

  db_subnet_group_name    = aws_db_subnet_group.securecart-rds.id
  vpc_security_group_ids  = [aws_security_group.securecart-rds-sg.id]

  publicly_accessible     = false
  multi_az = false
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = {
   Name = "${var.project}-Database"
  }
}