# C4 Permissions Stack - Outputs

output "professor_bindings" {
  description = "IAM bindings for professors"
  value = {
    for k, v in google_project_iam_member.professor_access :
    k => {
      email = var.professors[k].email
      role  = v.role
    }
  }
}

output "student_bindings" {
  description = "IAM bindings for students"
  value = {
    for k, v in google_project_iam_member.student_access :
    k => {
      email = var.students[k].email
      role  = v.role
    }
  }
}

output "service_account_bindings" {
  description = "IAM bindings for service accounts"
  value = {
    for k, v in google_project_iam_member.service_account_access :
    k => {
      email = var.service_accounts[k].email
      role  = v.role
    }
  }
}

output "billing_viewers" {
  description = "Users with billing viewer access"
  value       = var.billing_viewers
}

output "github_collaborators" {
  description = "GitHub repository collaborators"
  value = {
    for k, v in github_repository_collaborator.collaborators :
    k => {
      username   = v.username
      permission = v.permission
    }
  }
}
