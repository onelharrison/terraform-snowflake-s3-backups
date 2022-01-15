resource "random_id" "aws_resource_id" {
  byte_length  = 4
}

resource "aws_s3_bucket" "snowflake_backups_bucket" {
  bucket = "snowflake-backups-${lower(random_id.aws_resource_id.id)}"

  acl    = "private"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    id      = "backups"
    enabled = true

    tags = {
      rule      = "backups"
      autoclean = "true"
    }

    transition {
      days          = 7
      storage_class = "GLACIER"
    }

    expiration {
      days = 30
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role" "snowflake" {
  name = "snowflake"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = ""
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = { "AWS": "*" }
        Condition = {
          "StringLike": {
            "sts:ExternalId": "${data.snowflake_current_account.this.account}_SFCRole=*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "snowflake_s3_backups" {
  name       = "snowflake_s3_backups_policy_attachment"
  roles      = [aws_iam_role.snowflake.name]
  policy_arn = aws_iam_policy.snowflake_s3_backups_policy.arn
}

resource "aws_iam_policy" "snowflake_s3_backups_policy" {
  name   = "snowflake_s3_backups_policy"
  policy = data.aws_iam_policy_document.snowflake_s3_backups_policy_doc.json
}

data "aws_iam_policy_document" "snowflake_s3_backups_policy_doc" {
  statement {
    effect  = "Allow"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
    ]

    resources = [
      "arn:aws:s3:::${aws_s3_bucket.snowflake_backups_bucket.bucket}/*"
    ]
  }

  statement {
    effect  = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]

    resources = [
      "arn:aws:s3:::${aws_s3_bucket.snowflake_backups_bucket.bucket}"
    ]
  }
}
