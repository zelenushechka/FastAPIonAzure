###############################################################################
# Azure Container Apps
# - Log Analytics workspace for ACA logs
# - Container Apps Environment with VNET injection (internal load balancer)
# - Container App with user-assigned managed identity
# - Pulls image from ACR via private endpoint
# - Loads secrets from Key Vault via MI
###############################################################################

resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${var.app_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

###############################################################################
# Container Apps Environment
# - internal_load_balancer_enabled = true  → only reachable from the VNet
# - workload_profile required for /27-sized subnet
###############################################################################
resource "azurerm_container_app_environment" "this" {
  name                = "cae-${var.app_name}"
  location            = var.location
  resource_group_name = var.resource_group_name

  log_analytics_workspace_id     = azurerm_log_analytics_workspace.this.id
  infrastructure_subnet_id       = var.container_apps_subnet_id
  internal_load_balancer_enabled = true

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  tags = var.tags
}

###############################################################################
# Container App
###############################################################################
resource "azurerm_container_app" "this" {
  name                         = "ca-${var.app_name}"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [var.user_assigned_identity_id]
  }

  # Pull from ACR using the managed identity (no admin user, no passwords).
  registry {
    server   = var.acr_login_server
    identity = var.user_assigned_identity_id
  }

  # Reference Key Vault secrets directly. ACA resolves these via the MI at
  # container start; the actual value never appears in Terraform state.
  dynamic "secret" {
    for_each = var.key_vault_secret_refs
    content {
      name                = secret.value.name
      identity            = var.user_assigned_identity_id
      key_vault_secret_id = secret.value.key_vault_secret_id
    }
  }

  ingress {
    external_enabled           = false # internal-only via the environment's internal LB
    target_port                = 8000
    transport                  = "auto"
    allow_insecure_connections = false

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 1
    max_replicas = 5

    container {
      name   = var.app_name
      image  = var.container_image
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "STORAGE_ACCOUNT_NAME"
        value = var.storage_account_name
      }
      env {
        name  = "STORAGE_CONTAINER_NAME"
        value = var.storage_container_name
      }
      env {
        name  = "KEY_VAULT_URI"
        value = var.key_vault_uri
      }
      env {
        name  = "AZURE_CLIENT_ID"
        value = var.user_assigned_identity_client_id
      }

      # Expose Key Vault secrets as env vars referencing the secret refs above
      dynamic "env" {
        for_each = var.key_vault_secret_refs
        content {
          name        = upper(replace(env.value.name, "-", "_"))
          secret_name = env.value.name
        }
      }

      liveness_probe {
        path      = "/health"
        port      = 8000
        transport = "HTTP"
      }

      readiness_probe {
        path      = "/health"
        port      = 8000
        transport = "HTTP"
      }
    }

    http_scale_rule {
      name                = "http-scaler"
      concurrent_requests = 50
    }
  }

  lifecycle {
    ignore_changes = [
      # Image is rolled forward by the application deployment pipeline,
      # not the infra pipeline. Terraform only sets the initial value.
      template[0].container[0].image,
    ]
  }
}
