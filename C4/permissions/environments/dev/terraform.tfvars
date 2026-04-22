# C4 Permissions Stack - Development Environment

# Project Settings
project_id  = "fourth-outpost-479614-t4"
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
  lenny = {
    email = "lenny.vongphouthone@epitech.eu"
    role  = "roles/editor"
  }
  yorenn = {
    email = "yorennzzelina@hotmail.fr"
    role  = "roles/editor"
  }
  rayane = {
    email = "rayane.memiche@epitech.eu"
    role  = "roles/editor"
  }
  troxifox = {
    email = "thetroxifoxtran@gmail.com"
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

github_owner      = "Jouzep"
github_repository = "infra-as-code"

github_collaborators = {
  professor = {
    username   = "Kloox"
    permission = "pull"
  }
  lenny = {
    username   = "lennyvong"
    permission = "push"
  }
  yorenn = {
    username   = "yorennz"
    permission = "push"
  }
  rayane = {
    username   = "RayaneMemiche"
    permission = "push"
  }
  troxifox = {
    username   = "Troxifox"
    permission = "push"
  }
}
