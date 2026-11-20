$ErrorActionPreference = 'Stop'
$root = Join-Path ([IO.Path]::GetTempPath()) ('avm-password-test-' + [guid]::NewGuid().ToString('N'))
$saved = @{}
foreach ($name in @('GITHUB_ACTIONS', 'GITHUB_RUN_ID', 'GITHUB_RUN_ATTEMPT', 'TF_VAR_admin_password')) {
    $saved[$name] = [Environment]::GetEnvironmentVariable($name)
}

try {
    $null = New-Item -ItemType Directory -Path $root
    $examples = Join-Path (Split-Path $PSScriptRoot -Parent) 'examples'
    Copy-Item -LiteralPath (Join-Path $examples 'Set-CiAdminPassword.ps1') -Destination $root
    foreach ($example in @('default', 'backup-enabled')) {
        $directory = Join-Path $root $example
        $null = New-Item -ItemType Directory -Path $directory
        foreach ($hook in @('pre.ps1', 'post.ps1')) {
            Copy-Item -LiteralPath (Join-Path $examples $example $hook) -Destination $directory
        }
        $pre = Join-Path $directory 'pre.ps1'
        $post = Join-Path $directory 'post.ps1'
        $path = Join-Path $directory 'avm-ci-admin-password-123-1.auto.tfvars.json'
        $env:GITHUB_ACTIONS = 'false'
        $env:GITHUB_RUN_ID = '123'
        $env:GITHUB_RUN_ATTEMPT = '1'
        $env:TF_VAR_admin_password = $null
        & $pre
        if (Test-Path -LiteralPath $path) { throw "$example changed local password behavior." }

        $env:GITHUB_ACTIONS = 'true'
        $env:TF_VAR_admin_password = 'Caller-Supplied123!'
        & $pre
        if (Test-Path -LiteralPath $path) { throw "$example overrode a supplied password." }

        $env:TF_VAR_admin_password = $null
        $output = @(& $pre)
        if ($output.Count -ne 0) { throw "$example printed password preparation output." }
        $password = (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json).admin_password
        if ($password.Length -lt 12 -or $password.Length -gt 123 -or
            $password -cnotmatch '[a-z]' -or $password -cnotmatch '[A-Z]' -or
            $password -notmatch '[0-9]' -or $password -notmatch '[^a-zA-Z0-9]') {
            throw "$example generated an invalid Windows password."
        }
        & $pre
        if ((Get-Content -LiteralPath $path -Raw | ConvertFrom-Json).admin_password -cne $password) {
            throw "$example changed its password on repeated preparation."
        }
        & $post
        if (Test-Path -LiteralPath $path) { throw "$example did not clean up its generated input." }
        & $pre
        if ((Get-Content -LiteralPath $path -Raw | ConvertFrom-Json).admin_password -ceq $password) {
            throw "$example reused a password after cleanup."
        }
        & $post
        Write-Output "$example CI password hooks: passed"
    }
}
finally {
    foreach ($name in $saved.Keys) {
        [Environment]::SetEnvironmentVariable($name, $saved[$name])
    }
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
