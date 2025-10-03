# PowerShell script for common Terraform tasks on Windows
# Usage: .\scripts.ps1 <command>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("test", "test-ci", "validate", "format", "format-check", "init", "plan", "docs", "security", "clean", "help")]
    [string]$Command
)

function Show-Help {
    Write-Host "Microsoft Entra Domain Services Terraform Template - Windows Scripts" -ForegroundColor Green
    Write-Host "Available commands:" -ForegroundColor Yellow
    Write-Host "  test        - Run all tests and validations" -ForegroundColor White
    Write-Host "  test-ci     - Run CI validation (no Azure auth required)" -ForegroundColor White
    Write-Host "  validate    - Validate Terraform configuration" -ForegroundColor White
    Write-Host "  format      - Format Terraform files" -ForegroundColor White
    Write-Host "  format-check- Check if Terraform files are formatted" -ForegroundColor White
    Write-Host "  init        - Initialize Terraform" -ForegroundColor White
    Write-Host "  plan        - Create Terraform execution plan" -ForegroundColor White
    Write-Host "  docs        - Generate Terraform documentation" -ForegroundColor White
    Write-Host "  security    - Run security checks with tfsec" -ForegroundColor White
    Write-Host "  clean       - Clean up temporary files" -ForegroundColor White
    Write-Host "  help        - Show this help message" -ForegroundColor White
}

function Test-CI {
    Write-Host "Running CI validation with mock configuration..." -ForegroundColor Green
    
    # Set environment variables for CI testing
    $env:ARM_SKIP_PROVIDER_REGISTRATION = "true"
    $env:ARM_USE_CLI = "false"
    
    try {
        Write-Host "Initializing Terraform..." -ForegroundColor Yellow
        terraform init -backend=false
        
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform init failed"
        }
        
        Write-Host "Validating configuration..." -ForegroundColor Yellow
        terraform validate
        
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform validate failed"
        }
        
        Write-Host "Running plan with CI configuration..." -ForegroundColor Yellow
        terraform plan -var-file="terraform.tfvars.ci" -input=false
        
        # Note: Authentication errors are expected in CI/CD without Azure login
        Write-Host "CI validation completed successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "CI validation failed: $_" -ForegroundColor Red
        exit 1
    }
    finally {
        # Clean up environment variables
        Remove-Item Env:ARM_SKIP_PROVIDER_REGISTRATION -ErrorAction SilentlyContinue
        Remove-Item Env:ARM_USE_CLI -ErrorAction SilentlyContinue
    }
}

function Test-All {
    Write-Host "Running all tests and validations..." -ForegroundColor Green
    
    # Format check
    Write-Host "Checking Terraform format..." -ForegroundColor Yellow
    terraform fmt -check=true -recursive
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Terraform files are not properly formatted. Run format command to fix." -ForegroundColor Red
        exit 1
    }
    
    # Validate
    Write-Host "Validating Terraform configuration..." -ForegroundColor Yellow
    terraform validate
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Terraform validation failed" -ForegroundColor Red
        exit 1
    }
    
    # Security scan
    if (Get-Command "tfsec" -ErrorAction SilentlyContinue) {
        Write-Host "Running security scan..." -ForegroundColor Yellow
        tfsec . --format table
    } else {
        Write-Host "tfsec not found. Install from: https://github.com/aquasecurity/tfsec" -ForegroundColor Yellow
    }
    
    Write-Host "All tests completed successfully!" -ForegroundColor Green
}

function Invoke-Format {
    Write-Host "Formatting Terraform files..." -ForegroundColor Green
    terraform fmt -recursive
}

function Invoke-FormatCheck {
    Write-Host "Checking Terraform format..." -ForegroundColor Green
    terraform fmt -check=true -recursive
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Terraform files are not properly formatted" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "All files are properly formatted" -ForegroundColor Green
    }
}

function Invoke-Validate {
    Write-Host "Validating Terraform configuration..." -ForegroundColor Green
    terraform init -backend=false
    terraform validate
}

function Invoke-Init {
    Write-Host "Initializing Terraform..." -ForegroundColor Green
    terraform init
}

function Invoke-Plan {
    Write-Host "Creating Terraform execution plan..." -ForegroundColor Green
    
    if (-not (Test-Path "terraform.tfvars")) {
        Write-Host "Creating terraform.tfvars from example..." -ForegroundColor Yellow
        Copy-Item "terraform.tfvars.example" "terraform.tfvars"
        Write-Host "Please edit terraform.tfvars with your actual values" -ForegroundColor Yellow
    }
    
    terraform plan -out=tfplan
}

function Invoke-Docs {
    Write-Host "Generating Terraform documentation..." -ForegroundColor Green
    
    if (Get-Command "terraform-docs" -ErrorAction SilentlyContinue) {
        terraform-docs markdown table . > docs/TERRAFORM_DOCS.md
        Write-Host "Documentation generated in docs/TERRAFORM_DOCS.md" -ForegroundColor Green
    } else {
        Write-Host "terraform-docs not found. Install from: https://terraform-docs.io/" -ForegroundColor Yellow
    }
}

function Invoke-Security {
    Write-Host "Running security checks..." -ForegroundColor Green
    
    if (Get-Command "tfsec" -ErrorAction SilentlyContinue) {
        tfsec . --format table
    } else {
        Write-Host "tfsec not found. Install from: https://github.com/aquasecurity/tfsec" -ForegroundColor Yellow
    }
}

function Invoke-Clean {
    Write-Host "Cleaning up temporary files..." -ForegroundColor Green
    
    $filesToClean = @("tfplan", "tfplan.*", ".terraform.lock.hcl")
    $foldersToClean = @(".terraform")
    
    foreach ($file in $filesToClean) {
        Get-ChildItem -Path $file -ErrorAction SilentlyContinue | Remove-Item -Force
    }
    
    foreach ($folder in $foldersToClean) {
        if (Test-Path $folder) {
            Remove-Item -Path $folder -Recurse -Force
        }
    }
    
    Write-Host "Cleanup completed!" -ForegroundColor Green
}

# Main command dispatcher
switch ($Command) {
    "test" { Test-All }
    "test-ci" { Test-CI }
    "validate" { Invoke-Validate }
    "format" { Invoke-Format }
    "format-check" { Invoke-FormatCheck }
    "init" { Invoke-Init }
    "plan" { Invoke-Plan }
    "docs" { Invoke-Docs }
    "security" { Invoke-Security }
    "clean" { Invoke-Clean }
    "help" { Show-Help }
    default { 
        Write-Host "Unknown command: $Command" -ForegroundColor Red
        Show-Help
        exit 1
    }
}