resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(var.tags, { Name = "${var.username}" })
}

# 퍼블릭 서브넷 생성
resource "aws_subnet" "public" {
  count                   = length(var.public_subnets)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false # 퍼블릭 IP 자동 할당
  tags                    = merge(var.tags, { Name = "${var.username}-public-subnet-${count.index + 1}" })
}

# 인터넷 게이트웨이 생성
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.username}-igw" })
}

# 퍼블릭 라우트 테이블
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = merge(var.tags, { Name = "${var.username}-public-rt" })
}

# 서브넷과 라우트 테이블 연결
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "private" {
  count                   = length(var.private_subnets)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_subnets[count.index]
  availability_zone       = var.private_azs[count.index]
  map_public_ip_on_launch = false # 퍼블릭 IP 자동 할당
  tags = merge(var.tags, {
    Name                              = "${var.username}-private-subnet-${count.index + 1}"
    "kubernetes.io/role/internal-elb" = 1
  })
  lifecycle {
    ignore_changes = [
      tags["kubernetes.io/cluster/${module.eks.cluster_name}"],
    ]
  }
}

resource "aws_ec2_tag" "private_subnet_cluster_tag" {
  for_each    = local.cluster_subnets
  resource_id = each.value
  key         = "kubernetes.io/cluster/${var.eks_cluster_name}"
  value       = "owned"
}
