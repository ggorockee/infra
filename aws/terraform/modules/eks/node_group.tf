data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

# 0) EC2가 Assume 할 수 있는 Policy 문서
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# 1) IAM Role 생성
resource "aws_iam_role" "self_node_role" {
  for_each = var.self_managed_node_groups

  name               = "${each.value.name}-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "self_node_policies" {
  for_each = {
    for ng, policy in var.worker_policies : "${ng}-${basename(policy)}" => {
      ng     = ng
      policy = policy
    }
  }

  role       = aws_iam_role.self_node_role[each.value.ng].name
  policy_arn = each.value.policy
}


# 3) Instance Profile 생성
resource "aws_iam_instance_profile" "self_node_profile" {
  for_each = var.self_managed_node_groups

  name = "${each.value.name}-instance-profile"
  role = aws_iam_role.self_node_role[each.key].name
}



#----------------------------------------------------------------
# 3) EKS-Optimized AMI 가져오기
#----------------------------------------------------------------
data "aws_ami" "eks_worker" {
  most_recent = true
  owners      = ["602401143452"] # EKS official
  filter {
    name   = "name"
    values = ["amazon-eks-node-${var.eks_version}-*"]
  }
}

#----------------------------------------------------------------
# 4) User-data(bootstrap.sh) 구성
#----------------------------------------------------------------
data "template_cloudinit_config" "node_userdata" {
  for_each      = var.self_managed_node_groups
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/x-shellscript"
    content      = <<-EOF
      #!/bin/bash
      /etc/eks/bootstrap.sh ${module.eks.cluster_name} \
        --kubelet-extra-args '--node-labels=nodegroup=${each.value.name}'
    EOF
  }
}

#----------------------------------------------------------------
# 5) Launch Template
#----------------------------------------------------------------
resource "aws_launch_template" "self_node" {
  for_each      = var.self_managed_node_groups
  name_prefix   = "${each.value.name}-lt-"
  image_id      = data.aws_ami.eks_worker.id
  instance_type = each.value.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.self_node_profile[each.key].name
  }

  network_interfaces {
    security_groups             = [module.eks.node_security_group_id]
    associate_public_ip_address = false
  }

  user_data = base64encode(
    replace(
      data.template_cloudinit_config.node_userdata.rendered,
      # for_each를 활용하려면 template_cloudinit_config 을 locals 내에서 렌더링하거나
      # 본 예제처럼 static하게 사용하세요.
      "{{each.value.name}}", each.value.name
    )
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = each.value.name
      # 이 태그가 있어야 Kube API 서버가 노드를 인식합니다.
      "kubernetes.io/cluster/${module.eks.cluster_name}" = "owned"
    }
  }
}
