resource "aws_ecr_repository" "this" {
  for_each             = toset(var.repository_names)
  name                 = each.value
  image_tag_mutability = "IMMUTABLE" # a tag like build-25 can never be overwritten -> what you tested is what you deploy
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = true # ECR basic scanning checks every pushed image for known CVEs
  }

  encryption_configuration {
    encryption_type = "AES256" # images encrypted at rest (use "KMS" for a customer-managed key in prod)
  }

  tags = merge(var.tags, { Name = each.value })
}

# Lifecycle rules keep storage cost near zero
resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Delete untagged images after ${var.untagged_expire_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_expire_days
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only the last ${var.keep_last_tagged_images} tagged images"
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["*"]
          countType      = "imageCountMoreThan"
          countNumber    = var.keep_last_tagged_images
        }
        action = { type = "expire" }
      }
    ]
  })
}

# Repository policy: only the listed roles may pull / push. Everyone else in the account needs their own IAM permission.
data "aws_iam_policy_document" "repo" {
  count = length(var.pull_principal_arns) + length(var.push_principal_arns) > 0 ? 1 : 0

  dynamic "statement" {
    for_each = length(var.pull_principal_arns) > 0 ? [1] : []
    content {
      sid    = "AllowPull"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = var.pull_principal_arns
      }
      actions = ["ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage", "ecr:BatchCheckLayerAvailability"]
    }
  }

  dynamic "statement" {
    for_each = length(var.push_principal_arns) > 0 ? [1] : []
    content {
      sid    = "AllowPush"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = var.push_principal_arns
      }
      actions = [
        "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage", "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload",
      ]
    }
  }
}

resource "aws_ecr_repository_policy" "this" {
  for_each   = length(data.aws_iam_policy_document.repo) > 0 ? aws_ecr_repository.this : {}
  repository = each.value.name
  policy     = data.aws_iam_policy_document.repo[0].json
}
