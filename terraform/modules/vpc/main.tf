# Subnet layout (for vpc_cidr 10.0.0.0/16 and two AZs):
#   public      10.0.0.0/24   10.0.1.0/24     -> ALB, NAT gateway, Jenkins, SonarQube
#   private app 10.0.10.0/24  10.0.11.0/24    -> EKS worker nodes
#   private db  10.0.20.0/24  10.0.21.0/24    -> RDS MySQL
locals {
  az_count          = length(var.azs)
  public_cidrs      = [for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 8, i)]
  private_app_cidrs = [for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 8, 10 + i)]
  private_db_cidrs  = [for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 8, 20 + i)]
  nat_count         = var.single_nat_gateway ? 1 : local.az_count
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true # needed so pods and EC2 can resolve AWS service names
  enable_dns_hostnames = true # needed for RDS endpoints and EKS private endpoint
  tags                 = merge(var.tags, { Name = "${var.name}-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-igw" })
}

# ---------- Subnets ----------
resource "aws_subnet" "public" {
  count                   = local.az_count
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false # instances that need a public IP ask for one explicitly

  tags = merge(var.tags, {
    Name                                        = "${var.name}-public-${var.azs[count.index]}"
    Tier                                        = "public"
    "kubernetes.io/role/elb"                    = "1" # internet-facing load balancers go here
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

resource "aws_subnet" "private_app" {
  count             = local.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_app_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(var.tags, {
    Name                                        = "${var.name}-private-app-${var.azs[count.index]}"
    Tier                                        = "private-app"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

resource "aws_subnet" "private_db" {
  count             = local.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_db_cidrs[count.index]
  availability_zone = var.azs[count.index]
  tags              = merge(var.tags, { Name = "${var.name}-private-db-${var.azs[count.index]}", Tier = "private-db" })
}

# ---------- NAT gateway(s): lets private subnets reach the internet, but not the other way round ----------
resource "aws_eip" "nat" {
  count  = local.nat_count
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name}-nat-eip-${count.index}" })
}

resource "aws_nat_gateway" "this" {
  count         = local.nat_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id # a NAT gateway must live in a PUBLIC subnet
  tags          = merge(var.tags, { Name = "${var.name}-nat-${count.index}" })
  depends_on    = [aws_internet_gateway.this]
}

# ---------- Route tables ----------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-public-rt" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count          = local.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# One private route table per AZ; each points at "its" NAT gateway (or the single shared one)
resource "aws_route_table" "private_app" {
  count  = local.az_count
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-private-app-rt-${var.azs[count.index]}" })
}

resource "aws_route" "private_app_nat" {
  count                  = local.az_count
  route_table_id         = aws_route_table.private_app[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index].id
}

resource "aws_route_table_association" "private_app" {
  count          = local.az_count
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app[count.index].id
}

# Database subnets get NO route to the internet at all (no NAT, no IGW). They are reachable only inside the VPC.
resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-private-db-rt" })
}

resource "aws_route_table_association" "private_db" {
  count          = local.az_count
  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private_db.id
}

# ---------- VPC endpoint: S3 gateway endpoint is FREE and keeps S3 traffic (ECR image layers live in S3) off the NAT ----------
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(aws_route_table.private_app[*].id, [aws_route_table.private_db.id])
  tags              = merge(var.tags, { Name = "${var.name}-s3-endpoint" })
}
