$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Import-Module Avm.Authoring
$tool = Get-AvmTool -Name terraform -Path $root
if ($tool.Status -ne 'installed') {
    throw 'Run avm test unit first to initialize the managed Terraform toolchain.'
}

$testDirectory = Join-Path 'tests' 'unit'
$testFile = Join-Path $testDirectory 'defaults_and_outputs.tftest.hcl'
$exampleTestFile = Join-Path $testDirectory 'backup_example_location.tftest.hcl'
$lines = @(& $tool.Path "-chdir=$root" test "-test-directory=$testDirectory" "-filter=$testFile" "-filter=$exampleTestFile" -no-color -json -verbose)
$exitCode = $LASTEXITCODE
$events = @($lines | ForEach-Object { $_ | ConvertFrom-Json })
if ($exitCode -ne 0) {
    $details = @($events | Where-Object type -EQ 'diagnostic' | ForEach-Object { $_.diagnostic.detail }) -join "`n"
    throw "The mocked backup retention tests failed (exit $exitCode). $details"
}

# The backup child exports only its ID; inspect the plans to verify its persisted destroy request.
$expected = @{
    removes_backup_configuration_with_retention           = $true
    removes_backup_configuration_after_deletion_opt_in    = $false
}
foreach ($case in $expected.GetEnumerator()) {
    $plans = @($events | Where-Object { $_.type -eq 'test_plan' -and $_.'@testrun' -eq $case.Key })
    if ($plans.Count -ne 1) { throw "Expected one backup removal plan for $($case.Key)." }
    $changes = @($plans[0].test_plan.resource_changes | Where-Object address -EQ 'module.backup["vm1"].azapi_resource_action.backup_destroy')
    if ($changes.Count -ne 1 -or $changes[0].change.actions.Count -ne 1 -or $changes[0].change.actions[0] -ne 'delete') {
        throw "Expected destruction of the backup teardown action for $($case.Key)."
    }
    $request = $changes[0].change.before
    if ($request.when -ne 'destroy') { throw 'Backup teardown must run only on destroy.' }
    if ($case.Value) {
        if ($request.method -ne 'PUT' -or $request.body.properties.protectionState -ne 'ProtectionStopped') {
            throw 'The default backup removal must stop protection and retain recovery points.'
        }
    }
    elseif ($request.method -ne 'DELETE' -or $null -ne $request.body) {
        throw 'Backup removal must request deletion only after explicitly opting out of retention.'
    }
}
Write-Output 'Backup retention destroy requests: passed'

$states = @($events | Where-Object { $_.type -eq 'test_state' -and $_.'@testrun' -eq 'uses_east_us_for_backup_example' })
if ($states.Count -ne 1) { throw 'Expected one applied state for the disposable backup example.' }
$requests = @($states[0].test_state.root_module.child_modules |
    Where-Object address -EQ 'module.test' |
    ForEach-Object child_modules |
    Where-Object address -EQ 'module.test.module.backup["cvm1"]' |
    ForEach-Object resources |
    Where-Object name -EQ 'backup_destroy')
if ($requests.Count -ne 1) { throw 'Expected one backup teardown request for the disposable example.' }
$request = $requests[0].values
if ($request.when -ne 'destroy' -or $request.method -ne 'DELETE' -or $null -ne $request.body) {
    throw 'The disposable backup example must persist an explicit delete-on-destroy request.'
}
Write-Output 'Disposable backup example destroy request: passed'
