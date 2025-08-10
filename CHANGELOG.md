# Changelog

## [v1.0.0] – 2025-08-09
### Added
- **Initial release** of the Homelab automation project.
- **Infrastructure provisioning** using Terraform for:
  - AWS EC2 instance hosting the homelab.
- **Automated CI/CD** with GitHub Actions:
  - Provisioning and decommissioning workflows.
  - Automatic Cloudflare DNS update with new EC2 public IP.
  - SSH-based remote deployment and service startup.
- **Docker Compose-based service stack** deployment:
  - **Keycloak** – Identity & access management.
  - **Jenkins** – CI/CD automation.
  - **SonarQube** – Code quality and security scanning.
  - **Portainer** – Container management dashboard.
- **Secure networking** and DNS routing through Cloudflare.
- **Initial documentation** on setup and usage.