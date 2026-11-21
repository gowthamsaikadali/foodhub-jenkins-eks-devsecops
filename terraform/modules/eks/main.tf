resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 7 # keep log cost low
  tags              = var.tags
}

# Customer-managed key so Kubernetes Secrets stored in etcd are envelope-encrypted (cost: about 1 USD per month)
resource "aws_kms_key" "secrets" {
  description             = "${var.cluster_name} Kubernetes secrets encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  tags                    = var.tags
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.cluster_name}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true # nodes and Jenkins inside the VPC talk to the API privately
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
  }

  # "API" mode = permissions come from EKS access entries (modern). The old aws-auth ConfigMap is not used.
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.secrets.arn
    }
  }

  enabled_cluster_log_types = var.cluster_log_types
  tags                      = var.tags

  depends_on = [aws_cloudwatch_log_group.cluster]
}

# ---------- Worker nodes (private subnets only) ----------
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name}-nodes"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnet_ids
  ami_type        = "AL2023_x86_64_STANDARD"
  capacity_type   = "ON_DEMAND"
  instance_types  = var.node_instance_types
  disk_size       = var.node_disk_size_gb

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  tags = merge(var.tags, { Name = "${var.name}-nodes" })

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size] # let the cluster autoscaler / manual scaling own this number
  }

  depends_on = [aws_eks_addon.vpc_cni]
}

# ---------- Add-ons ----------
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_update = "OVERWRITE"

  # Turns on Kubernetes NetworkPolicy enforcement in the AWS VPC CNI. Without this the policies in
  # kubernetes/network-policies would be accepted by the API but silently NOT enforced.
  configuration_values = jsonencode({ enableNetworkPolicy = "true" })
  tags                        = var.tags
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags
  depends_on                  = [aws_eks_node_group.main]
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "coredns"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags
  depends_on                  = [aws_eks_node_group.main] # CoreDNS pods need nodes to run on
}

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "eks-pod-identity-agent"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags
  depends_on                  = [aws_eks_node_group.main]
}

# ---------- Access entries: who may use kubectl ----------
resource "aws_eks_access_entry" "admins" {
  for_each      = toset(var.admin_principal_arns)
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admins" {
  for_each      = aws_eks_access_entry.admins
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_access_entry" "jenkins" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.jenkins_role_arn
  type          = "STANDARD"
}

# Jenkins may edit workloads ONLY in the "foodhub" namespace: it cannot touch other namespaces or cluster-wide objects.
resource "aws_eks_access_policy_association" "jenkins" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_eks_access_entry.jenkins.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = [var.app_namespace]
  }
}

# ---------- AWS Load Balancer Controller: IAM role through EKS Pod Identity ----------
data "aws_iam_policy_document" "pod_identity_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "lbc" {
  name   = "${var.name}-aws-load-balancer-controller"
  policy = file("${path.module}/lbc_iam_policy.json") # official policy from the controller project
  tags   = var.tags
}

resource "aws_iam_role" "lbc" {
  name               = "${var.name}-aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "lbc" {
  role       = aws_iam_role.lbc.name
  policy_arn = aws_iam_policy.lbc.arn
}

# Binds Kubernetes ServiceAccount kube-system/aws-load-balancer-controller to the IAM role above
resource "aws_eks_pod_identity_association" "lbc" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.lbc.arn
  depends_on      = [aws_eks_addon.pod_identity_agent]
}
