terraform {
  backend "s3" {
    bucket         = "movie-review-state"   # ← replace with your bucket name
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "movie-review-lock"        # ← DynamoDB table for locking
    encrypt        = true
  }
}
