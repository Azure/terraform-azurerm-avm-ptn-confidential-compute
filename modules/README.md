# Submodules

- [Confidential virtual machine](confidential-virtual-machine/README.md): Deploys Linux or Windows confidential VMs,
  network interfaces, optional managed data disks and attachments, and optional backup protection using an existing vault policy.

The [root pattern module](../README.md) composes this submodule and supplies shared location and tag defaults.
Direct submodule consumers must provide a location in every VM definition.

Submodule README files are generated from Terraform and `_header.md` / `_footer.md` sources with `avm docs` at the repository root.
