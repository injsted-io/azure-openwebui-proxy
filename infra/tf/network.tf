data "aws_vpc" "default" {
  default = true
}

# AZs in this region that actually offer your instance type (e.g., t3.large)
data "aws_ec2_instance_type_offerings" "supported" {
  filter {
    name   = "instance-type"
    values = [var.instance_type]
  }
  location_type = "availability-zone"
}

# Pick only the default (public) subnets that are in supported AZs
data "aws_subnets" "public_supported" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
  filter {
    name   = "availability-zone"
    values = data.aws_ec2_instance_type_offerings.supported.locations
  }
}

resource "aws_security_group" "openwebui_sg" {
  name        = "openwebui-sg"
  description = "Allow Open WebUI and outbound"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Open WebUI HTTP"
    from_port   = 3020
    to_port     = 3020
    protocol    = "tcp"
    cidr_blocks = [var.ingress_cidr] # e.g., "YOUR.IP/32"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
