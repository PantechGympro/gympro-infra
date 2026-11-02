terraform {
  required_version = ">= 1.6.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }

  # Backend remoto con bloqueo de estado nativo (HCP Terraform / Terraform Cloud).
  # No se pueden interpolar variables dentro de un bloque "cloud"/"backend" (restricción
  # del propio Terraform) — por eso los entornos se separan con *workspaces* de Terraform
  # (ver terraform/README.md: "terraform workspace new staging / production"), no con un
  # nombre de workspace fijo por tfvars.
  #
  # IMPORTANTE antes del primer `terraform init`: reemplaza "pantechgympro" por el slug
  # real de tu organización en https://app.terraform.io (es gratis, créala si no existe).
  cloud {
    organization = "pantechgympro"
    workspaces {
      tags = ["gympro-infra"]
    }
  }
}
