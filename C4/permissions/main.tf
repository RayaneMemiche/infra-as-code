# C4 Permissions Stack - Main Configuration
# This stack manages IAM permissions separately from infrastructure

# ============================================================================
# PROFESSOR ACCESS
# ============================================================================

resource "google_project_iam_member" "professor_access" {
  for_each = var.professors

  project = var.project_id
  role    = each.value.role
  member  = "user:${each.value.email}"
}

# ============================================================================
# STUDENT ACCESS
# ============================================================================

resource "google_project_iam_member" "student_access" {
  for_each = var.students

  project = var.project_id
  role    = each.value.role
  member  = "user:${each.value.email}"
}

# ============================================================================
# SERVICE ACCOUNT ACCESS (External)
# ============================================================================

resource "google_project_iam_member" "service_account_access" {
  for_each = var.service_accounts

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${each.value.email}"
}

# ============================================================================
# BILLING ACCOUNT ACCESS
# ============================================================================

resource "google_billing_account_iam_member" "billing_viewer" {
  for_each = var.billing_viewers

  billing_account_id = var.billing_account_id
  role               = "roles/billing.viewer"
  member             = "user:${each.value}"
}

# ============================================================================
# GITHUB REPOSITORY ACCESS
# ============================================================================

resource "github_repository_collaborator" "collaborators" {
  for_each = var.github_collaborators

  repository = var.github_repository
  username   = each.value.username
  permission = each.value.permission
}
