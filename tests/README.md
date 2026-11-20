# Tests

Use PowerShell 7.4 or later and [Avm.Authoring](https://github.com/Azure/azure-verified-modules-tools#install).
Run commands from the repository root after importing the module:

```powershell
Import-Module Avm.Authoring
avm test
avm test unit
pwsh -NoProfile -File .\tests\ci_admin_password.tests.ps1
```

## Unit coverage

Provider-mocked Terraform tests live in [unit](unit/):

- [Windows backup example](unit/backup_example_location.tftest.hcl): The resource group, virtual network, and backup vault
  use East US without random region selection. The pattern exercises the published AVM VM and backup modules.
  The policy must explicitly use Enhanced (`V2`) to avoid Azure rejecting the default Standard policy.
  Instant-restore retention must be explicit, positive, and strictly shorter than vaulted daily retention.
- [Disk defaults and Linux VM composition](unit/data_disk_tags.tftest.hcl): The root pattern preserves tag inheritance,
  explicit empty overrides, and disk zones independent of the VM's zone. The AVM VM receives the confidential
  security defaults and supports Linux password authentication alongside the supplied SSH key.
- [Disk and backup validation](unit/data_disk_validations.tftest.hcl): Rejects duplicate LUNs, invalid caching modes,
  backup selection of undeclared LUNs, and a policy ID pointing to a different vault.
- [Defaults and outputs](unit/defaults_and_outputs.tftest.hcl): Root region and tag defaults and VM and managed disk IDs.
- [Telemetry location](unit/telemetry_location_validation.tftest.hcl): The required root region supplies VM defaults
  and telemetry; VM region overrides do not change telemetry's region.
- [Windows VM and default example](unit/windows.tftest.hcl): Exercises the Windows confidential security profile and
  the default example's East US deployment using the root pattern and published AVM VM module.

Mocked `apply` does not deploy Azure resources, prove regional SKU
availability or quota, or verify backup and restore.

The [CI password hook tests](ci_admin_password.tests.ps1) exercise both examples without Azure.
They verify local no-op behavior, preservation of supplied passwords, valid generated passwords without console output,
stable inputs across repeated preparation, cleanup, and regeneration after cleanup. Run this PowerShell suite
separately from `avm test unit`, which discovers only the Terraform tests.

## Other test tiers

| Command | Scope | Azure deployment |
| --- | --- | --- |
| `avm test` | Terraform initialization and validation; no unit or E2E runs | No |
| `avm test integration` | Real-Azure tests under `tests/integration`; none are currently authored | Only when tests exist |
| `avm test e2e --list` | List runnable examples | No |
| `avm test e2e` | Apply, idempotency-check, and attempt cleanup of both examples | Yes |

An absent integration suite is skipped, not passed.
Read the [examples guide](../examples/README.md) before E2E testing: it requires Azure authentication and can incur charges.

For contribution checks, run `avm pre-commit`, review the resulting changes, and run `avm pr-check` only after committing a clean worktree.
See the [contribution guide](../CONTRIBUTING.md). Do not commit credentials, private keys, state, or unredacted deployment logs.
