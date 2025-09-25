variable "ecr_repositories" {
  description = "생성할 ECR 리포지토리 목록"
  type = list(object({
    name               = string
    scan_on_push       = optional(bool, true)
    image_tag_mutable  = optional(bool, true)
    keep_last          = optional(number, 10)
  }))
  default = [
    { name = "hair-model-creator" },
    { name = "household-ledger" },
    { name = "gary-saju-service" },
    { name = "spark-prompt" },
    { name = "liview-backend",  keep_last = 15 },
    { name = "react-wedding-invitation-letter" },
    { name = "liview-frontend", keep_last = 15 },
  ]
}

resource "aws_ecr_repository" "this" {
  for_each = { for repo in var.ecr_repositories : repo.name => repo }

  name                 = each.value.name
  image_tag_mutability = each.value.image_tag_mutable ? "MUTABLE" : "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = each.value.scan_on_push
  }

  tags = local.default_tags
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.this

  repository = each.value.name
  policy     = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only latest images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = local.ecr_keep_last_by_name[each.key]
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

locals {
  ecr_keep_last_by_name = { for r in var.ecr_repositories : r.name => (try(r.keep_last, 10)) }
}

