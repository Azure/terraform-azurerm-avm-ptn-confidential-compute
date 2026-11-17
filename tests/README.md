# Tests

Use PowerShell 7.4 or later and [Avm.Authoring](https://github.com/Azure/azure-verified-modules-tools#install).
Run commands from the repository root after importing the module:

```powershell
Import-Module Avm.Authoring
avm test unit
avm test
```

## Unit coverage

Provider-mocked Terraform tests live in [unit](unit/):

- [Windows backup example](unit/backup_example_location.tftest.hcl): The resource group, virtual network, and backup vault
  use East US without random region selection; the real pattern and VM submodule exercise the Windows VM and backup-protection paths.
- [Data-disk tags](unit/data_disk_tags.tftest.hcl): The real VM submodule accepts omitted disk and VM tags, inherits VM tags,
  and preserves explicit overrides and empty maps.
- [Data-disk validation](unit/data_disk_validations.tftest.hcl): Duplicate LUNs, backup selection of an undeclared LUN,
  and invalid caching modes are rejected.
- [Defaults and outputs](unit/defaults_and_outputs.tftest.hcl): Root location/tag defaults and selected output forwarding.
- [Telemetry location](unit/telemetry_location_validation.tftest.hcl): Missing locations are rejected and a VM-level location can supply telemetry's region.
- [Windows default example](unit/windows.tftest.hcl): The default example creates its resource group in East US and exercises
  the Windows VM path through the root pattern and real VM submodule with mocked providers.

There are nine test runs across these six files. Root-interface tests override the confidential VM submodule.
The disk-tag and both Windows-example tests exercise the real module implementation with mocked providers.
Mocked `apply` does not deploy Azure resources, prove regional SKU
availability or quota, or verify backup and restore.

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
