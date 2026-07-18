function Resolve-DotnetHarnessPython {
    $candidates = New-Object System.Collections.Generic.List[string]
    if ($env:DOTNET_HARNESS_PYTHON) {
        $candidates.Add($env:DOTNET_HARNESS_PYTHON)
    }

    foreach ($name in @("python3.13", "python3.12", "python3.11", "python", "python3")) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command -and $command.Source) {
            $candidates.Add($command.Source)
        }
    }

    $launcher = Get-Command py -ErrorAction SilentlyContinue
    if ($launcher) {
        foreach ($selector in @("-3.13", "-3.12", "-3.11", "-3")) {
            $resolved = & $launcher.Source $selector -c "import sys; print(sys.executable)" 2>$null
            if ($LASTEXITCODE -eq 0 -and $resolved) {
                $candidates.Add(([string]$resolved).Trim())
                break
            }
        }
    }

    foreach ($candidate in $candidates | Select-Object -Unique) {
        if (-not (Test-Path -LiteralPath $candidate)) {
            continue
        }
        & $candidate -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)" 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $candidate
        }
    }

    throw "Python 3.11 or newer is required. Set DOTNET_HARNESS_PYTHON or install Python."
}
