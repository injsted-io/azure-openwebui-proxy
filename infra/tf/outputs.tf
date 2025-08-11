locals {
  public_host = coalesce(
    try(aws_eip.webui.public_ip, null),
    try(aws_instance.openwebui.public_ip, null)
  )
}

output "openwebui_http_url" {
  description = "HTTP URL (no TLS) for Open WebUI if a public IP/EIP exists"
  value       = local.public_host != null ? "http://${local.public_host}:3020" : "NO_PUBLIC_IP"
}

output "eip_public_ip" {
  description = "Elastic IP (if allocated)"
  value       = try(aws_eip.webui.public_ip, null)
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.openwebui.id
}

output "private_ip" {
  description = "Instance private IPv4 (use with VPN/SSM/port-forward)"
  value       = aws_instance.openwebui.private_ip
}

output "security_group_id" {
  description = "Security group protecting Open WebUI"
  value       = aws_security_group.openwebui_sg.id
}

output "availability_zone" {
  value       = aws_instance.openwebui.availability_zone
  description = "EC2 AZ"
}

output "ami_id" {
  value       = data.aws_ami.al2023.id
  description = "AMI used for the instance"
}
