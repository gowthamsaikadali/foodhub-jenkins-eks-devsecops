locals {
  cluster_arn = "arn:aws:eks:${var.region}:${var.account_id}:cluster/${var.cluster_name}"
  ecr_arns    = [for n in var.ecr_repository_names : "arn:aws:ecr:${var.region}:${var.account_id}:repository/${n}"]
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "eks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

# ===================== 1. EKS control plane role =====================
resource "aws_iam_role" "eks_cluster" {
  name               = "${var.name}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ===================== 2. EKS worker node role =====================
resource "aws_iam_role" "eks_node" {
  name               = "${var.name}-eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_node" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly", # lets nodes pull images from ECR: no imagePullSecrets needed
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",       # shell access through SSM instead of SSH keys
  ])
  role       = aws_iam_role.eks_node.name
  policy_arn = each.value
}

# ===================== 3. Jenkins EC2 role (application pipeline, least privilege) =====================
resource "aws_iam_role" "jenkins" {
  name               = "${var.name}-jenkins-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = var.tags
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.name}-jenkins-profile"
  role = aws_iam_role.jenkins.name
}

resource "aws_iam_role_policy_attachment" "jenkins_ssm" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "jenkins" {
  # ecr:GetAuthorizationToken cannot be limited to a repository, so it needs Resource "*"
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPushPullOnFoodHubRepositoriesOnly"
    actions = [
      "ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage",
      "ecr:DescribeImages", "ecr:DescribeRepositories", "ecr:ListImages",
    ]
    resources = local.ecr_arns
  }

  statement {
    sid       = "DescribeTheClusterToBuildKubeconfig"
    actions   = ["eks:DescribeCluster"]
    resources = [local.cluster_arn]
  }

  statement {
    sid       = "AssumeTheTerraformRoleForInfrastructurePipelineOnly"
    actions   = ["sts:AssumeRole"]
    resources = [aws_iam_role.terraform.arn]
  }
}

resource "aws_iam_role_policy" "jenkins" {
  name   = "${var.name}-jenkins-app-pipeline"
  role   = aws_iam_role.jenkins.id
  policy = data.aws_iam_policy_document.jenkins.json
}

# ===================== 4. Terraform deployer role (infrastructure pipeline only) =====================
# Jenkins' own role cannot create infrastructure. The infrastructure pipeline assumes THIS role for the duration of a run.
data "aws_iam_policy_document" "terraform_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = concat([aws_iam_role.jenkins.arn], var.extra_trusted_principal_arns)
    }
  }
}

resource "aws_iam_role" "terraform" {
  name                 = "${var.name}-terraform-deployer"
  assume_role_policy   = data.aws_iam_policy_document.terraform_assume.json
  max_session_duration = 3600
  tags                 = var.tags
}

data "aws_iam_policy_document" "terraform" {
  statement {
    sid = "ServicesTerraformManages"
    actions = [
      "ec2:*", "eks:*", "rds:*", "ecr:*", "elasticloadbalancing:*", "autoscaling:*",
      "secretsmanager:*", "kms:*", "logs:*", "cloudwatch:*", "ssm:GetParameter", "ssm:GetParameters",
      "sts:GetCallerIdentity", "budgets:*",
    ]
    resources = ["*"]
  }

  # IAM is the dangerous one, so it is limited to roles/policies whose NAME starts with the project prefix
  statement {
    sid = "IamOnlyForProjectPrefixedRoles"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateRole", "iam:TagRole", "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy",
      "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile", "iam:GetInstanceProfile",
      "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile", "iam:TagInstanceProfile",
      "iam:CreatePolicy", "iam:DeletePolicy", "iam:GetPolicy", "iam:GetPolicyVersion", "iam:ListPolicyVersions",
      "iam:CreatePolicyVersion", "iam:DeletePolicyVersion", "iam:TagPolicy",
      "iam:PassRole", "iam:CreateServiceLinkedRole",
    ]
    resources = [
      "arn:aws:iam::${var.account_id}:role/${var.name}-*",
      "arn:aws:iam::${var.account_id}:instance-profile/${var.name}-*",
      "arn:aws:iam::${var.account_id}:policy/${var.name}-*",
      "arn:aws:iam::${var.account_id}:role/aws-service-role/*",
    ]
  }

  statement {
    sid       = "IamReadOnly"
    actions   = ["iam:GetOpenIDConnectProvider", "iam:ListRoles", "iam:ListPolicies"]
    resources = ["*"]
  }

  statement {
    sid       = "TerraformStateBucket"
    actions   = ["s3:ListBucket", "s3:GetBucketVersioning", "s3:GetBucketLocation"]
    resources = ["arn:aws:s3:::${var.state_bucket_name}"]
  }

  statement {
    sid       = "TerraformStateObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${var.state_bucket_name}/*"]
  }
}

resource "aws_iam_role_policy" "terraform" {
  name   = "${var.name}-terraform-deployer-policy"
  role   = aws_iam_role.terraform.id
  policy = data.aws_iam_policy_document.terraform.json
}
