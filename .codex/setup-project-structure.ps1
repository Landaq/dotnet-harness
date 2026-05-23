param(
    [string]$Root = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Set-Location -LiteralPath $Root

$directories = @(
    'src/Aspire/AppHost',
    'src/Aspire/ServiceDefaults',
    'src/FrontEnd/Web',
    'src/FrontEnd/Web.Client',
    'src/BackEnd/APIGateway',
    'src/BackEnd/BuildingBlocks/Contracts',
    'src/BackEnd/BuildingBlocks/Messaging',
    'src/BackEnd/BuildingBlocks/Observability',
    'src/BackEnd/Services/_template/_template.Domain/Aggregates',
    'src/BackEnd/Services/_template/_template.Domain/Entities',
    'src/BackEnd/Services/_template/_template.Domain/ValueObjects',
    'src/BackEnd/Services/_template/_template.Domain/Events',
    'src/BackEnd/Services/_template/_template.Domain/Repositories',
    'src/BackEnd/Services/_template/_template.Application/Abstractions',
    'src/BackEnd/Services/_template/_template.Application/UseCases/Commands',
    'src/BackEnd/Services/_template/_template.Application/UseCases/Queries',
    'src/BackEnd/Services/_template/_template.Application/DTOs',
    'src/BackEnd/Services/_template/_template.Application/Validators',
    'src/BackEnd/Services/_template/_template.Infrastructure/Persistence/Configurations',
    'src/BackEnd/Services/_template/_template.Infrastructure/Persistence/Migrations',
    'src/BackEnd/Services/_template/_template.Infrastructure/Repositories',
    'src/BackEnd/Services/_template/_template.Infrastructure/Integrations',
    'src/BackEnd/Services/_template/_template.Api/Endpoints',
    'src/BackEnd/Services/_template/_template.Api/Mapping',
    'src/BackEnd/Services/_template/_template.Contracts/Requests',
    'src/BackEnd/Services/_template/_template.Contracts/Responses',
    'src/BackEnd/Services/_template/_template.Contracts/IntegrationEvents',
    'test/Architecture',
    'test/Unit/Services/_template',
    'test/Integration/Services/_template',
    'test/Contract/Services/_template',
    'test/Functional/APIGateway',
    'test/Functional/FrontEnd',
    'test/EndToEnd',
    'docs/architecture',
    'docs/decisions',
    'docs/testing'
)

foreach ($directory in $directories) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $gitKeepPath = Join-Path $directory '.gitkeep'
    if (-not (Test-Path -LiteralPath $gitKeepPath)) {
        New-Item -ItemType File -Path $gitKeepPath | Out-Null
    }
}

Write-Host "Created or verified $($directories.Count) directories under $Root"
Write-Host "Target backend structure: src/BackEnd/Services/{ServiceName} with BuildingBlocks."
