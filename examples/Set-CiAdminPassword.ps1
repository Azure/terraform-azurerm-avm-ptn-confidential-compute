param(
    [Parameter(Mandatory)]
    [string]$ExamplePath,
    [switch]$Cleanup
)

$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true') { return }
if ($env:GITHUB_RUN_ID -notmatch '^\d+$' -or $env:GITHUB_RUN_ATTEMPT -notmatch '^\d+$') {
    throw 'CI password preparation requires a GitHub Actions run ID and attempt.'
}

$path = Join-Path $ExamplePath "avm-ci-admin-password-$env:GITHUB_RUN_ID-$env:GITHUB_RUN_ATTEMPT.auto.tfvars.json"
if ($Cleanup) {
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Force -ErrorAction Stop
    }
    return
}
if (-not [string]::IsNullOrEmpty($env:TF_VAR_admin_password) -or (Test-Path -LiteralPath $path)) { return }

$password = 'aA1!' + [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
$content = @{ admin_password = $password } | ConvertTo-Json -Compress
$options = [IO.FileStreamOptions]::new()
$options.Mode = [IO.FileMode]::CreateNew
$options.Access = [IO.FileAccess]::Write
$options.Share = [IO.FileShare]::None
if (-not $IsWindows) {
    $options.UnixCreateMode = [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite
}
$stream = [IO.File]::Open($path, $options)
try {
    $bytes = [Text.Encoding]::UTF8.GetBytes($content)
    $stream.Write($bytes, 0, $bytes.Length)
}
finally {
    $stream.Dispose()
}
