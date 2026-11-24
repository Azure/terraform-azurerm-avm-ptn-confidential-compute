# Examples

- [Default](default/README.md): One Windows Server 2025 Datacenter Gen2 confidential VM (`Standard_DC2ads_v5`),
  an AzAPI-based AVM resource group named `rg-ckhy` by default, networking prerequisites, and a 128-GB managed data disk.
- [Backup enabled](backup-enabled/README.md): One Windows Server 2025 Datacenter Gen2 confidential VM (`Standard_DC2as_v5`),
  networking prerequisites, a Recovery Services vault,
  a daily Enhanced (`V2`) backup policy, and a VM protection association. No additional data disks are created.

The baseline example retains the legacy `default` directory name for migration compatibility.
Current [AVM required-example guidance](https://azure.github.io/Azure-Verified-Modules/spec/TFNFR42/) uses `defaults`
for new pattern modules; a `waf-aligned` example is optional. Neither scenario claims WAF compliance.

## Run examples

Use PowerShell 7.4 or later and [Avm.Authoring](https://github.com/Azure/azure-verified-modules-tools#install).
Read each example's prerequisites first. Both examples require an administrator password; tags are optional.
Run these commands from the repository root, supplying the password without putting it in command history:

```powershell
Import-Module Avm.Authoring
avm test e2e --list
$env:TF_VAR_admin_password = Read-Host 'Windows administrator password' -MaskInput
avm test e2e --example default
avm test e2e --example backup-enabled
Remove-Item Env:\TF_VAR_admin_password
```

If testing stops before cleanup, remove the password environment variable from the terminal afterward.
Deployment tests require an authenticated Azure identity and incur Azure charges.
Use your intended test subscription; a subscription ID alone does not authenticate.
The runner initializes, applies, checks idempotency, and attempts to destroy each selected example.
Inspect cleanup failures and remaining resources rather than assuming a failed test left nothing deployed.
Running `avm test e2e` without `--example` selects both examples sequentially.
The default example manages and destroys its resource group during cleanup; do not use a group containing unrelated resources.

The backup-enabled example requests backup data deletion on destroy and verifies that vault soft delete remains enabled.
Read its [cleanup and data-loss guidance](backup-enabled/README.md#cleanup-and-data-loss) before running E2E:
retained or soft-deleted backup items can prevent vault deletion.

To select a region or disable telemetry for an example, set Terraform environment variables in the same terminal:

```powershell
$env:TF_VAR_location = 'eastus'
$env:TF_VAR_enable_telemetry = 'false'
```

Both examples default to East US (`eastus`) without random region selection. Their regional resources and telemetry
use the selected `location`; subnets and backup policies inherit the location of their parent resources.
Both examples default telemetry to enabled and forward the option to their modules.
Verify that your Azure authentication and the AzAPI provider target the intended subscription before planning.
Regenerate saved plans after configuration or subscription changes and review any planned replacements.
Protect state files and saved plans: both examples store the administrator password.

## CI password behavior

Both examples use PowerShell `pre.ps1` and `post.ps1` hooks for managed policy checks and E2E tests.
In GitHub Actions only, the pre-hook generates a cryptographically random Windows password when
`TF_VAR_admin_password` is not supplied. It writes an ignored, run-specific `*.auto.tfvars.json` file
without printing the password. Repeated preparation reuses the same input so idempotency checks do not rotate it.
The post-hook removes the generated input; state and saved plans still contain the password and must be protected.
On Unix runners the generated input is readable and writable only by its owner.
Local runs are unchanged: supply the required password yourself. Do not retain or upload generated CI inputs.

## Validate and document

```powershell
avm test
avm docs
```

`avm test` initializes and validates Terraform; it does not run unit tests or deploy the examples.
`avm docs` generates the root, submodule, and example README files from Terraform and their `_header.md` / `_footer.md` sources.
Do not edit generated README files directly.
