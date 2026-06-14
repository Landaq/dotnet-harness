param(
    [string]$PluginRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
)

. (Join-Path $PSScriptRoot "common.ps1")
$ctx = Get-DotnetHarnessValidationContext -PluginRoot $PluginRoot

function Invoke-ScaffoldBuildSmoke {
    param(
        [string]$Name,
        [string]$ProjectName,
        [string]$ServiceName
    )

    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("dotnet-harness-smoke-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    try {
        $installArgs = @("-NoProfile", "-File", $ctx.InstallScript, "-Root", $root, "-ProjectName", $ProjectName)
        if ($ServiceName) {
            $installArgs += @("-ServiceName", $ServiceName)
        }
        else {
            $installArgs += "-NoService"
        }
        & pwsh @installArgs
        if ($LASTEXITCODE -ne 0) {
            throw "$Name scaffold install failed."
        }

        $solution = Join-Path $root "$ProjectName.slnx"
        if (-not (Test-Path -LiteralPath $solution)) {
            throw "$Name did not create expected solution: $solution"
        }

        Push-Location $root
        try {
            Invoke-CheckedCommand -Name "$Name restore" -Command @("dotnet", "restore", "$ProjectName.slnx")
            Invoke-CheckedCommand -Name "$Name build" -Command @("dotnet", "build", "$ProjectName.slnx", "--no-restore")
            Invoke-CheckedCommand -Name "$Name test" -Command @("dotnet", "test", "$ProjectName.slnx", "--no-build")
        }
        finally {
            Pop-Location
        }
    }
    finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Invoke-ValidationStep "no-service scaffold restore/build/test" {
    Invoke-ScaffoldBuildSmoke -Name "no-service scaffold" -ProjectName "SmokeNoService"
}

Invoke-ValidationStep "with-service scaffold restore/build/test" {
    Invoke-ScaffoldBuildSmoke -Name "with-service scaffold" -ProjectName "SmokeWithService" -ServiceName "Auth"
}

Write-Host "Scaffold validation passed: $($ctx.PluginRoot)"
