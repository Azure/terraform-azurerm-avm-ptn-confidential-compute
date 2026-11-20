$ErrorActionPreference = 'Stop'
& (Join-Path (Split-Path $PSScriptRoot -Parent) 'Set-CiAdminPassword.ps1') -ExamplePath $PSScriptRoot
