data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"] # or: ["137112412989"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "openwebui" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = element(sort(data.aws_subnets.public_supported.ids), 0) # from network.tf
  vpc_security_group_ids = [aws_security_group.openwebui_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = var.key_name

  # ensure egress during first boot; EIP replaces it moments later
  associate_public_ip_address = true

  # force a replace when user_data changes so cloud-init re-runs
  user_data_replace_on_change = true

  # stricter metadata + nicer monitoring (optional, but good defaults)
  metadata_options {
    http_tokens = "required"
  }
  monitoring = true

  user_data = templatefile("${path.module}/user-data.sh", {
    region     = var.aws_region
    ssm_prefix = var.ssm_prefix
  })

  root_block_device {
    volume_size           = 40 # plenty of headroom for images
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  tags = { Name = "openwebui" }
}

# Static public IP
resource "aws_eip" "webui" {
  domain = "vpc"
  tags   = { Name = "openwebui-eip" }
}

resource "aws_eip_association" "webui" {
  instance_id   = aws_instance.openwebui.id
  allocation_id = aws_eip.webui.id
}