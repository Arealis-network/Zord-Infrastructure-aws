variable "environment" {
  description = "Deployment environment (staging or production)."
  type        = string
}

variable "eks_name_prefix" {
  description = "Human-readable resource name prefix (e.g. 'Arealis zord prod eks')."
  type        = string
}

variable "eks_resource_prefix" {
  description = "DNS/resource-safe prefix (e.g. 'arealis-zord-prod-eks')."
  type        = string
}

variable "vpc_id" {
  description = "VPC the RDS instance is placed in."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block. RDS allows inbound 5432 from within this CIDR (matches the app NetworkPolicy egress)."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the DB subnet group (RDS is not publicly reachable)."
  type        = list(string)
}

variable "cluster_security_group_id" {
  description = "EKS cluster security group. RDS ingress on 5432 is locked to this SG so only the cluster can reach the database."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for RDS storage encryption."
  type        = string
}

############################
# sizing (free-tier defaults — change to scale to paid)
############################

variable "instance_class" {
  description = "RDS instance class. Free-tier: db.t3.micro. Scale later to db.t3.small / db.t3.medium (one-line change)."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Storage in GB. Free tier covers 20 GB."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Storage autoscaling ceiling in GB. Set equal to allocated_storage to disable autoscaling (stay in free tier)."
  type        = number
  default     = 20
}

variable "multi_az" {
  description = "Multi-AZ standby for HA failover. NOT free tier — leave false until production paid tier."
  type        = bool
  default     = false
}

variable "engine_version" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "16"
}

variable "backup_retention_days" {
  description = "Automated backup retention in days. Free tier includes backup storage up to the DB size."
  type        = number
  default     = 7
}

variable "master_username" {
  description = "RDS master username. NOTE: 'postgres', 'admin', 'root' are RESERVED by RDS and will be rejected — use a custom name."
  type        = string
  default     = "zordadmin"
}

variable "storage_type" {
  description = "RDS storage type. Free tier uses gp2. gp3 is faster but not free-tier eligible."
  type        = string
  default     = "gp2"
}



variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs allowed inbound on 5432 (nodes/pods). SEC H3 — replaces the broad VPC-CIDR rule so the DB is never reachable from public subnets/bastion."
  type        = list(string)
}

variable "deletion_protection" {
  description = "SEC H2 — protect the DB from accidental deletion. Default false for dev teardown; set true in production."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "SEC H2 — skip final snapshot on destroy. Default true for dev; set false in production so a snapshot is taken before deletion."
  type        = bool
  default     = true
}

variable "force_ssl" {
  description = "SEC M4 — enforce TLS on all DB connections via rds.force_ssl parameter group."
  type        = bool
  default     = true
}
