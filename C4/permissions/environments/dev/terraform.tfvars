# C4 Permissions Stack - Development Environment

# Project Settings
project_id  = "iac-rattrapage-epitech"
region      = "europe-west1"
environment = "dev"

# ============================================================================
# TEAM ACCESS
# ============================================================================

# Professors (read-only access + billing)
professors = {
  jjaouen = {
    email = "jeremie@jjaouen.com"
    role  = "roles/viewer"
  }
}

# Students (editor access)
students = {
  rayane = {
    email = "rayane.memiche@epitech.eu"
    role  = "roles/editor"
  }
}

# External Service Accounts (if needed)
service_accounts = {}

# ============================================================================
# BILLING ACCESS
# ============================================================================

billing_account_id = "01387B-7CABD9-464F50"
billing_viewers    = ["jeremie@jjaouen.com"]

# ============================================================================
# GITHUB ACCESS
# ============================================================================

github_owner      = "RayaneMemiche"
github_repository = "infra-as-code"

github_collaborators = {
  professor = {
    username   = "Kloox"
    permission = "pull"
  }
  rayane = {
    username   = "RayaneMemiche"
    permission = "push"
  }
}
