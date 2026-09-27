#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
terraform_dir="${repo_dir}/terraform"

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform is required: https://developer.hashicorp.com/terraform/install" >&2
  exit 1
fi

# Provider binaries cannot execute from some Windows-mounted WSL paths. Keep
# Terraform's working directory on the Linux filesystem in that case.
if [[ -z "${TF_DATA_DIR:-}" && "${repo_dir}" == /mnt/* ]]; then
  task_terraform_data="${TMPDIR:-/tmp}/hybrid-tgw-terraform-${UID}"
  mkdir -p "${task_terraform_data}"
  export TF_DATA_DIR="${task_terraform_data}"
fi

terraform -chdir="${terraform_dir}" fmt -check -recursive
terraform -chdir="${terraform_dir}" init -backend=false -input=false
terraform -chdir="${terraform_dir}" validate

echo "Terraform formatting and validation passed."
