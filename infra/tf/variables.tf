variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "t3.large"
}

variable "ingress_cidr" {
  type        = string
  description = "CIDR allowed to reach port 3020, e.g., YOUR.IP/32"
}

variable "s3_bucket_name" {
  type    = string
  default = "openwebui-storage-dss"
}

variable "ssm_prefix" {
  type    = string
  default = "/openwebui"
}

variable "key_name" {
  type    = string
  default = null
}
