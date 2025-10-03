# Makefile for Terraform Microsoft Entra Domain Services Template
# Provides common development and validation tasks

.PHONY: help init validate plan apply destroy format lint security docs clean test

# Default target
help: ## Show this help message
	@echo "Microsoft Entra Domain Services Terraform Template"
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Terraform commands
init: ## Initialize Terraform
	@echo "Initializing Terraform..."
	terraform init

validate: init ## Validate Terraform configuration
	@echo "Validating Terraform configuration..."
	terraform validate

format: ## Format Terraform files
	@echo "Formatting Terraform files..."
	terraform fmt -recursive

format-check: ## Check if Terraform files are formatted correctly
	@echo "Checking Terraform format..."
	terraform fmt -check=true -recursive

plan: validate ## Create Terraform execution plan
	@echo "Creating Terraform plan..."
	@if [ ! -f terraform.tfvars ]; then \
		echo "Creating sample terraform.tfvars from example..."; \
		cp terraform.tfvars.example terraform.tfvars; \
		echo "Please edit terraform.tfvars with your actual values"; \
	fi
	terraform plan -out=tfplan

apply: plan ## Apply Terraform configuration
	@echo "Applying Terraform configuration..."
	@echo "WARNING: This will create real Azure resources and may incur costs!"
	@read -p "Are you sure you want to continue? (y/N): " confirm && [ "$$confirm" = "y" ]
	terraform apply tfplan

destroy: ## Destroy Terraform-managed resources
	@echo "WARNING: This will destroy all Terraform-managed resources!"
	@read -p "Are you sure you want to continue? (y/N): " confirm && [ "$$confirm" = "y" ]
	terraform destroy

# Linting and security
lint: format-check validate ## Run all linting checks

security: ## Run security checks with tfsec
	@echo "Running security checks..."
	@if command -v tfsec >/dev/null 2>&1; then \
		tfsec . --format table; \
	else \
		echo "tfsec not found. Install it from: https://github.com/aquasecurity/tfsec"; \
		echo "Or run: curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash"; \
	fi

# Documentation
docs: ## Generate Terraform documentation
	@echo "Generating Terraform documentation..."
	@if command -v terraform-docs >/dev/null 2>&1; then \
		terraform-docs markdown table . > docs/TERRAFORM_DOCS.md; \
		echo "Documentation generated in docs/TERRAFORM_DOCS.md"; \
	else \
		echo "terraform-docs not found. Install it from: https://terraform-docs.io/user-guide/installation/"; \
	fi

# Testing and validation
test: format-check validate security ## Run all tests and validations
	@echo "All tests completed successfully!"

test-local: ## Run local validation with sample data
	@echo "Running local validation with sample data..."
	@cp terraform.tfvars.example terraform.tfvars.test
	@sed -i 's/yourdomain.com/test-domain.local/g' terraform.tfvars.test
	@sed -i 's/# "admin@yourdomain.com"/"admin@test-domain.local"/g' terraform.tfvars.test
	terraform init -backend=false
	terraform validate
	TF_VAR_file="terraform.tfvars.test" terraform plan -out=tfplan.test
	@rm -f terraform.tfvars.test tfplan.test
	@echo "Local validation completed successfully!"

# Cost estimation
cost: ## Estimate costs with Infracost
	@echo "Estimating costs..."
	@if command -v infracost >/dev/null 2>&1; then \
		if [ ! -f terraform.tfvars ]; then \
			cp terraform.tfvars.example terraform.tfvars; \
		fi; \
		terraform plan -out=tfplan.cost; \
		infracost breakdown --path=. --terraform-plan-path=tfplan.cost; \
		rm -f tfplan.cost; \
	else \
		echo "Infracost not found. Install it from: https://www.infracost.io/docs/#quick-start"; \
	fi

# Cleanup
clean: ## Clean up temporary files
	@echo "Cleaning up temporary files..."
	@rm -f tfplan tfplan.* terraform.tfvars.test
	@rm -rf .terraform/
	@rm -f .terraform.lock.hcl
	@echo "Cleanup completed!"

# Development helpers
dev-setup: ## Set up development environment
	@echo "Setting up development environment..."
	@echo "Installing required tools..."
	@if command -v brew >/dev/null 2>&1; then \
		echo "Installing with Homebrew..."; \
		brew install terraform terraform-docs tfsec infracost; \
	elif command -v apt-get >/dev/null 2>&1; then \
		echo "Installing with apt-get..."; \
		curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -; \
		sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $$(lsb_release -cs) main"; \
		sudo apt-get update && sudo apt-get install terraform; \
		curl -sSLo ./terraform-docs.tar.gz https://terraform-docs.io/dl/v0.16.0/terraform-docs-v0.16.0-$$(uname)-amd64.tar.gz; \
		tar -xzf terraform-docs.tar.gz; \
		sudo mv terraform-docs /usr/local/bin/; \
		rm terraform-docs.tar.gz; \
		curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash; \
	else \
		echo "Please manually install: terraform, terraform-docs, tfsec, and infracost"; \
	fi
	@echo "Development environment setup completed!"

check-tools: ## Check if required tools are installed
	@echo "Checking required tools..."
	@command -v terraform >/dev/null 2>&1 && echo "✓ Terraform installed" || echo "✗ Terraform not found"
	@command -v terraform-docs >/dev/null 2>&1 && echo "✓ terraform-docs installed" || echo "✗ terraform-docs not found"
	@command -v tfsec >/dev/null 2>&1 && echo "✓ tfsec installed" || echo "✗ tfsec not found"
	@command -v infracost >/dev/null 2>&1 && echo "✓ infracost installed" || echo "✗ infracost not found"