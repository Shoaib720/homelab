output "url" {
  value = { for k, repo in aws_ecr_repository.ecr : k => repo.repository_url }
}