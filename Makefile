SHELL := /usr/bin/env bash

.PHONY: fmt check init plan apply destroy outputs

fmt:
	terraform -chdir=terraform fmt -recursive

check:
	./scripts/check.sh

init:
	terraform -chdir=terraform init

plan:
	terraform -chdir=terraform plan -out=hybrid.tfplan

apply:
	terraform -chdir=terraform apply hybrid.tfplan

destroy:
	terraform -chdir=terraform destroy

outputs:
	terraform -chdir=terraform output

