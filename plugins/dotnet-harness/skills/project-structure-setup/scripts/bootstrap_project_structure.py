#!/usr/bin/env python3
"""Create folder skeleton from PROJECT_STRUCTURE.md-like architecture rules."""

from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path

BASE_DIRS = [
    "src/Aspire/AppHost",
    "src/Aspire/ServiceDefaults",
    "src/FrontEnd/Web",
    "src/FrontEnd/Web.Client",
    "src/BackEnd/APIGateway",
    "src/BackEnd/BuildingBlocks/Contracts",
    "src/BackEnd/BuildingBlocks/Messaging",
    "src/BackEnd/BuildingBlocks/Observability",
    "test/Architecture",
    "test/Unit",
    "test/Integration",
    "test/Contract",
    "test/Functional/APIGateway",
    "test/Functional/FrontEnd",
    "test/EndToEnd",
]

BUILDING_BLOCK_DIRS = [
    "src/BackEnd/BuildingBlocks/Application/Mediator",
    "src/BackEnd/BuildingBlocks/Application/Behaviors",
    "src/BackEnd/BuildingBlocks/Persistence",
]

SERVICE_LAYERS = {
    "Domain": [
        "Aggregates",
        "Entities",
        "ValueObjects",
        "Events",
        "Repositories",
    ],
    "Application": [
        "Abstractions",
        "UseCases/Commands",
        "UseCases/Queries",
        "DTOs",
        "Validators",
    ],
    "Infrastructure": [
        "Persistence/Configurations",
        "Persistence/Migrations",
        "Repositories",
        "Integrations",
    ],
    "Api": [
        "Endpoints",
        "Mapping",
    ],
    "Contracts": [
        "Requests",
        "Responses",
        "IntegrationEvents",
    ],
}

TEST_SERVICE_DIRS = [
    "test/Unit/Services/{service}",
    "test/Integration/Services/{service}",
    "test/Contract/Services/{service}",
]

PROJECT_README = """# Project Structure

This project structure was created by `project-structure-setup`.

## Stack

- Language: C#
- Framework: .NET 10
- Orchestration: Aspire
- Architecture: Clean Architecture + DDD
- Backend: ASP.NET Core, EF Core, Minimal API
- API docs: Scalar UI
- RDB: MS SQL Server
- NoSQL/cache: Redis
- Proxy: ASP.NET Core YARP
- Frontend: Blazor Auto Rendering + MudBlazor
- Application flow: mediator-like in-process request dispatcher

## Baseline Folders

- `src/Aspire/AppHost`
- `src/Aspire/ServiceDefaults`
- `src/FrontEnd/Web`
- `src/FrontEnd/Web.Client`
- `src/BackEnd/APIGateway`
- `src/BackEnd/BuildingBlocks/Contracts`
- `src/BackEnd/BuildingBlocks/Application`
- `src/BackEnd/BuildingBlocks/Messaging`
- `src/BackEnd/BuildingBlocks/Observability`
- `src/BackEnd/BuildingBlocks/Persistence`
- `test/Architecture`
- `test/Unit`
- `test/Integration`
- `test/Contract`
- `test/Functional/APIGateway`
- `test/Functional/FrontEnd`
- `test/EndToEnd`

## Workflow

Run `dotnet-harness:project-structure-setup` before `dotnet-harness:task-agents`.

After this baseline exists, `dotnet-harness:task-agents` can route work through workflow guardrails, intake planning, implementation coordination, specialist analysis, serial implementation, review, verification, and explicit git operations.
"""

def _project_files(project_name: str, service_name: str | None) -> dict[str, str]:
    safe_project = project_name or "DotnetHarness"
    service = service_name or "Sample"
    files = {
        ".gitignore": """# Build output
bin/
obj/
out/
dist/
build/

# .NET and test artifacts
TestResults/
*.trx
*.coverage
*.coveragexml
coverage/

# IDE and editor
.vs/
.vscode/
.idea/
*.user
*.suo
*.userosscache
*.sln.docstates

# Local environment and secrets
.env
.env.*
*.local
secrets.json
appsettings.*.local.json
appsettings.Development.local.json

# Logs and temp files
*.log
logs/
tmp/
temp/
*.tmp
*.cache

# OS files
Thumbs.db
Desktop.ini
.DS_Store

# Local git worktrees
.worktree/

# Package caches
node_modules/
packages/
.nuget/

# Generated reports
coverage-report/
playwright-report/
""",
        ".gitattributes": """* text=auto

.gitattributes text eol=lf

*.md text eol=lf
*.json text eol=lf
*.py text eol=lf
*.toml text eol=lf
*.yaml text eol=lf
*.yml text eol=lf
*.xml text eol=lf
*.props text eol=lf
*.targets text eol=lf
*.cs text eol=lf
*.csproj text eol=lf
*.slnx text eol=lf

*.ps1 text eol=crlf
*.psm1 text eol=crlf
*.cmd text eol=crlf
*.bat text eol=crlf
""",
        "global.json": """{
  "sdk": {
    "version": "10.0.300",
    "rollForward": "latestFeature"
  }
}
""",
        "Directory.Build.props": """<Project>
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <TreatWarningsAsErrors>false</TreatWarningsAsErrors>
  </PropertyGroup>
</Project>
""",
        "Directory.Packages.props": """<Project>
  <PropertyGroup>
    <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
  </PropertyGroup>
  <ItemGroup>
    <PackageVersion Include="Aspire.Hosting.AppHost" Version="13.0.0" />
    <PackageVersion Include="Aspire.Hosting.SqlServer" Version="13.0.0" />
    <PackageVersion Include="Aspire.Hosting.Redis" Version="13.0.0" />
    <PackageVersion Include="Microsoft.AspNetCore.Components.WebAssembly" Version="10.0.0" />
    <PackageVersion Include="Microsoft.AspNetCore.Components.WebAssembly.Server" Version="10.0.0" />
    <PackageVersion Include="Microsoft.EntityFrameworkCore.SqlServer" Version="10.0.0" />
    <PackageVersion Include="Microsoft.AspNetCore.OpenApi" Version="10.0.0" />
    <PackageVersion Include="Microsoft.Extensions.DependencyInjection.Abstractions" Version="10.0.0" />
    <PackageVersion Include="MudBlazor" Version="8.0.0" />
    <PackageVersion Include="Scalar.AspNetCore" Version="2.0.0" />
    <PackageVersion Include="StackExchange.Redis" Version="2.8.0" />
    <PackageVersion Include="Yarp.ReverseProxy" Version="2.3.0" />
  </ItemGroup>
</Project>
""",
        "src/Aspire/AppHost/AppHost.csproj": """<Project Sdk="Microsoft.NET.Sdk">
  <Sdk Name="Aspire.AppHost.Sdk" Version="13.0.0" />
  <PropertyGroup>
    <OutputType>Exe</OutputType>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Aspire.Hosting.AppHost" />
    <PackageReference Include="Aspire.Hosting.SqlServer" />
    <PackageReference Include="Aspire.Hosting.Redis" />
    <ProjectReference Include="..\\..\\BackEnd\\APIGateway\\APIGateway.csproj" />
    <ProjectReference Include="..\\..\\FrontEnd\\Web\\Web.csproj" />
  </ItemGroup>
</Project>
""",
        "src/Aspire/AppHost/Program.cs": f"""var builder = DistributedApplication.CreateBuilder(args);

var sql = builder.AddSqlServer("sql").AddDatabase("{safe_project}Db");
var redis = builder.AddRedis("redis");

var apiGateway = builder.AddProject<Projects.APIGateway>("api-gateway")
    .WithReference(sql)
    .WithReference(redis);

builder.AddProject<Projects.Web>("web")
    .WithReference(apiGateway);

builder.Build().Run();
""",
        "src/Aspire/ServiceDefaults/ServiceDefaults.csproj": """<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <IsAspireSharedProject>true</IsAspireSharedProject>
  </PropertyGroup>
  <ItemGroup>
    <FrameworkReference Include="Microsoft.AspNetCore.App" />
    <PackageReference Include="Microsoft.AspNetCore.OpenApi" />
  </ItemGroup>
</Project>
""",
        "src/Aspire/ServiceDefaults/Extensions.cs": """using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace ServiceDefaults;

public static class Extensions
{
    public static IHostApplicationBuilder AddServiceDefaults(this IHostApplicationBuilder builder)
    {
        builder.Services.AddOpenApi();
        builder.Services.AddHealthChecks();
        return builder;
    }

    public static WebApplication MapDefaultEndpoints(this WebApplication app)
    {
        app.MapHealthChecks("/health");
        return app;
    }
}
""",
        "src/BackEnd/APIGateway/APIGateway.csproj": """<Project Sdk="Microsoft.NET.Sdk.Web">
  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.OpenApi" />
    <PackageReference Include="Scalar.AspNetCore" />
    <PackageReference Include="Yarp.ReverseProxy" />
  </ItemGroup>
</Project>
""",
        "src/BackEnd/APIGateway/Program.cs": """using Scalar.AspNetCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();
builder.Services.AddReverseProxy()
    .LoadFromConfig(builder.Configuration.GetSection("ReverseProxy"));

var app = builder.Build();

app.MapOpenApi();
app.MapScalarApiReference();
app.MapReverseProxy();
app.MapGet("/api/health", () => Results.Ok(new { status = "ok" }));

app.Run();
""",
        "src/BackEnd/APIGateway/appsettings.json": """{
  "ReverseProxy": {
    "Routes": {},
    "Clusters": {}
  }
}
""",
        "src/BackEnd/BuildingBlocks/Contracts/Contracts.csproj": """<Project Sdk="Microsoft.NET.Sdk" />
""",
        "src/BackEnd/BuildingBlocks/Application/Application.csproj": """<Project Sdk="Microsoft.NET.Sdk">
  <ItemGroup>
    <PackageReference Include="Microsoft.Extensions.DependencyInjection.Abstractions" />
  </ItemGroup>
</Project>
""",
        "src/BackEnd/BuildingBlocks/Application/Mediator/IRequest.cs": """namespace BuildingBlocks.Application.Mediator;

public interface IRequest<out TResponse>
{
}
""",
        "src/BackEnd/BuildingBlocks/Application/Mediator/IRequestHandler.cs": """namespace BuildingBlocks.Application.Mediator;

public interface IRequestHandler<in TRequest, TResponse>
    where TRequest : IRequest<TResponse>
{
    Task<TResponse> Handle(TRequest request, CancellationToken cancellationToken);
}
""",
        "src/BackEnd/BuildingBlocks/Application/Mediator/IRequestDispatcher.cs": """namespace BuildingBlocks.Application.Mediator;

public interface IRequestDispatcher
{
    Task<TResponse> Send<TResponse>(IRequest<TResponse> request, CancellationToken cancellationToken = default);
}
""",
        "src/BackEnd/BuildingBlocks/Application/Mediator/RequestDispatcher.cs": """using Microsoft.Extensions.DependencyInjection;

namespace BuildingBlocks.Application.Mediator;

public sealed class RequestDispatcher(IServiceProvider serviceProvider) : IRequestDispatcher
{
    public Task<TResponse> Send<TResponse>(IRequest<TResponse> request, CancellationToken cancellationToken = default)
    {
        var handlerType = typeof(IRequestHandler<,>).MakeGenericType(request.GetType(), typeof(TResponse));
        dynamic handler = serviceProvider.GetRequiredService(handlerType);
        return handler.Handle((dynamic)request, cancellationToken);
    }
}
""",
        "src/BackEnd/BuildingBlocks/Messaging/Messaging.csproj": """<Project Sdk="Microsoft.NET.Sdk" />
""",
        "src/BackEnd/BuildingBlocks/Observability/Observability.csproj": """<Project Sdk="Microsoft.NET.Sdk" />
""",
        "src/BackEnd/BuildingBlocks/Persistence/Persistence.csproj": """<Project Sdk="Microsoft.NET.Sdk">
  <ItemGroup>
    <PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" />
    <PackageReference Include="StackExchange.Redis" />
  </ItemGroup>
</Project>
""",
        "src/FrontEnd/Web/Web.csproj": """<Project Sdk="Microsoft.NET.Sdk.Web">
  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.Components.WebAssembly.Server" />
    <PackageReference Include="MudBlazor" />
    <ProjectReference Include="..\\Web.Client\\Web.Client.csproj" />
  </ItemGroup>
</Project>
""",
        "src/FrontEnd/Web/Program.cs": """using MudBlazor.Services;
using Web;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents()
    .AddInteractiveWebAssemblyComponents();
builder.Services.AddMudServices();

var app = builder.Build();

app.UseHttpsRedirection();
app.UseAntiforgery();
app.MapStaticAssets();
app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode()
    .AddInteractiveWebAssemblyRenderMode();

app.Run();
""",
        "src/FrontEnd/Web/App.razor": """<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <base href="/" />
    <title>Dotnet Harness</title>
    <HeadOutlet />
</head>
<body>
    <Routes />
    <script src="_framework/blazor.web.js"></script>
</body>
</html>
""",
        "src/FrontEnd/Web/_Imports.razor": """@using Microsoft.AspNetCore.Components.Routing
@using Microsoft.AspNetCore.Components.Web
@using MudBlazor
""",
        "src/FrontEnd/Web/Routes.razor": """<Router AppAssembly="typeof(Program).Assembly">
    <Found Context="routeData">
        <RouteView RouteData="routeData" />
    </Found>
</Router>
""",
        "src/FrontEnd/Web/Pages/Home.razor": """@page "/"

<MudText Typo="Typo.h4">Dotnet Harness</MudText>
<MudText>Blazor Auto Rendering + MudBlazor baseline.</MudText>
""",
        "src/FrontEnd/Web.Client/Web.Client.csproj": """<Project Sdk="Microsoft.NET.Sdk.BlazorWebAssembly">
  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.Components.WebAssembly" />
    <PackageReference Include="MudBlazor" />
  </ItemGroup>
</Project>
""",
        "src/FrontEnd/Web.Client/Program.cs": """using Microsoft.AspNetCore.Components.WebAssembly.Hosting;
using MudBlazor.Services;

var builder = WebAssemblyHostBuilder.CreateDefault(args);
builder.Services.AddMudServices();
await builder.Build().RunAsync();
""",
        "src/FrontEnd/Web.Client/_Imports.razor": """@using Microsoft.AspNetCore.Components.Web
@using MudBlazor
""",
        f"src/BackEnd/Services/{service}/{service}.Domain/{service}.Domain.csproj": """<Project Sdk="Microsoft.NET.Sdk" />
""",
        f"src/BackEnd/Services/{service}/{service}.Application/{service}.Application.csproj": f"""<Project Sdk="Microsoft.NET.Sdk">
  <ItemGroup>
    <ProjectReference Include="..\\{service}.Domain\\{service}.Domain.csproj" />
    <ProjectReference Include="..\\{service}.Contracts\\{service}.Contracts.csproj" />
    <ProjectReference Include="..\\..\\..\\BuildingBlocks\\Application\\Application.csproj" />
  </ItemGroup>
</Project>
""",
        f"src/BackEnd/Services/{service}/{service}.Infrastructure/{service}.Infrastructure.csproj": f"""<Project Sdk="Microsoft.NET.Sdk">
  <ItemGroup>
    <PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" />
    <PackageReference Include="StackExchange.Redis" />
    <ProjectReference Include="..\\{service}.Application\\{service}.Application.csproj" />
  </ItemGroup>
</Project>
""",
        f"src/BackEnd/Services/{service}/{service}.Api/{service}.Api.csproj": f"""<Project Sdk="Microsoft.NET.Sdk.Web">
  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.OpenApi" />
    <PackageReference Include="Scalar.AspNetCore" />
    <ProjectReference Include="..\\{service}.Application\\{service}.Application.csproj" />
    <ProjectReference Include="..\\{service}.Infrastructure\\{service}.Infrastructure.csproj" />
  </ItemGroup>
</Project>
""",
        f"src/BackEnd/Services/{service}/{service}.Api/Program.cs": f"""using Scalar.AspNetCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();

var app = builder.Build();

app.MapOpenApi();
app.MapScalarApiReference();
app.MapGet("/api/{service.lower()}/health", () => Results.Ok(new {{ service = "{service}", status = "ok" }}));

app.Run();
""",
        f"src/BackEnd/Services/{service}/{service}.Contracts/{service}.Contracts.csproj": """<Project Sdk="Microsoft.NET.Sdk" />
""",
        "src/Aspire/AppHost/Properties/launchSettings.json": """{
  "$schema": "https://json.schemastore.org/launchsettings.json",
  "profiles": {
    "http": {
      "commandName": "Project",
      "dotnetRunMessages": true,
      "launchBrowser": true,
      "applicationUrl": "http://localhost:15000",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development",
        "DOTNET_DASHBOARD_OTLP_ENDPOINT_URL": "http://localhost:18888",
        "DOTNET_RESOURCE_SERVICE_ENDPOINT_URL": "http://localhost:18889"
      }
    },
    "https": {
      "commandName": "Project",
      "dotnetRunMessages": true,
      "launchBrowser": true,
      "applicationUrl": "https://localhost:17000;http://localhost:15000",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development",
        "DOTNET_DASHBOARD_OTLP_ENDPOINT_URL": "https://localhost:18888",
        "DOTNET_RESOURCE_SERVICE_ENDPOINT_URL": "https://localhost:18889"
      }
    }
  }
}
""",
        "src/FrontEnd/Web/Properties/launchSettings.json": """{
  "$schema": "https://json.schemastore.org/launchsettings.json",
  "profiles": {
    "http": {
      "commandName": "Project",
      "dotnetRunMessages": true,
      "launchBrowser": true,
      "applicationUrl": "http://localhost:15010",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    },
    "https": {
      "commandName": "Project",
      "dotnetRunMessages": true,
      "launchBrowser": true,
      "applicationUrl": "https://localhost:17010;http://localhost:15010",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    }
  }
}
""",
        "src/BackEnd/APIGateway/Properties/launchSettings.json": """{
  "$schema": "https://json.schemastore.org/launchsettings.json",
  "profiles": {
    "http": {
      "commandName": "Project",
      "dotnetRunMessages": true,
      "launchBrowser": true,
      "applicationUrl": "http://localhost:15020",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    },
    "https": {
      "commandName": "Project",
      "dotnetRunMessages": true,
      "launchBrowser": true,
      "applicationUrl": "https://localhost:17020;http://localhost:15020",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    }
  }
}
""",
        f"src/BackEnd/Services/{service}/{service}.Api/Properties/launchSettings.json": f"""{{
  "$schema": "https://json.schemastore.org/launchsettings.json",
  "profiles": {{
    "http": {{
      "commandName": "Project",
      "dotnetRunMessages": true,
      "launchBrowser": true,
      "applicationUrl": "http://localhost:15030",
      "environmentVariables": {{
        "ASPNETCORE_ENVIRONMENT": "Development"
      }}
    }},
    "https": {{
      "commandName": "Project",
      "dotnetRunMessages": true,
      "launchBrowser": true,
      "applicationUrl": "https://localhost:17030;http://localhost:15030",
      "environmentVariables": {{
        "ASPNETCORE_ENVIRONMENT": "Development"
      }}
    }}
  }}
}}
""",
    }
    if service_name is None:
        files = {key: value for key, value in files.items() if "/Services/" not in key}
    return files


def _solution_projects(service_name: str | None) -> list[str]:
    projects = [
        "src/Aspire/AppHost/AppHost.csproj",
        "src/Aspire/ServiceDefaults/ServiceDefaults.csproj",
        "src/BackEnd/APIGateway/APIGateway.csproj",
        "src/BackEnd/BuildingBlocks/Contracts/Contracts.csproj",
        "src/BackEnd/BuildingBlocks/Application/Application.csproj",
        "src/BackEnd/BuildingBlocks/Messaging/Messaging.csproj",
        "src/BackEnd/BuildingBlocks/Observability/Observability.csproj",
        "src/BackEnd/BuildingBlocks/Persistence/Persistence.csproj",
        "src/FrontEnd/Web/Web.csproj",
        "src/FrontEnd/Web.Client/Web.Client.csproj",
    ]
    if service_name:
        service = service_name
        projects.extend(
            [
                f"src/BackEnd/Services/{service}/{service}.Domain/{service}.Domain.csproj",
                f"src/BackEnd/Services/{service}/{service}.Application/{service}.Application.csproj",
                f"src/BackEnd/Services/{service}/{service}.Infrastructure/{service}.Infrastructure.csproj",
                f"src/BackEnd/Services/{service}/{service}.Api/{service}.Api.csproj",
                f"src/BackEnd/Services/{service}/{service}.Contracts/{service}.Contracts.csproj",
            ]
        )
    return projects

HARNESS_DIRS = [
    ".codex/agents",
    ".codex/scripts",
]

HARNESS_FILES = [
    "AGENTS.md",
]


def _normalize_name(value: str) -> str:
    return value.strip().replace(" ", "")


def _prompt_project_name() -> str:
    while True:
        try:
            value = input("프로젝트 이름(ProjectName)을 입력해 주세요: ").strip()
        except EOFError:
            raise SystemExit("--project-name is required when --project-name is not provided.")
        if value:
            return value
        print("Project name cannot be empty. Please enter again.")


def _prompt_service_name() -> str | None:
    try:
        value = input("서비스 이름(ServiceName)을 입력해 주세요(비우면 서비스 생성 생략): ").strip()
    except EOFError:
        return None
    if not value:
        return None
    return value


def _service_dirs(service: str) -> list[str]:
    root = f"src/BackEnd/Services/{service}"
    paths = [root]
    for layer, subs in SERVICE_LAYERS.items():
        layer_root = f"{root}/{service}.{layer}"
        paths.append(layer_root)
        for sub in subs:
            paths.append(f"{layer_root}/{sub}")
    for test_root in TEST_SERVICE_DIRS:
        paths.append(test_root.format(service=service))
    return paths


def collect_dirs(base_root: Path, service_name: str | None) -> list[Path]:
    target_root = base_root

    dirs = [target_root / p for p in [*BASE_DIRS, *BUILDING_BLOCK_DIRS]]
    dirs.append(target_root / "docs/Project")
    if service_name:
        dirs.extend([target_root / p for p in _service_dirs(service_name)])
    return dirs


def ensure_gitkeep(path: Path) -> None:
    marker = path / ".gitkeep"
    if not marker.exists():
        marker.write_text("")


def ensure_project_readme(target_root: Path, preview: bool) -> None:
    readme = target_root / "docs/Project/README.md"
    if preview:
        print(f"[preview] {readme}")
        return
    if readme.exists():
        print(f"[exists] {readme}")
        return
    readme.parent.mkdir(parents=True, exist_ok=True)
    readme.write_text(PROJECT_README, encoding="utf-8")
    print(f"[create] {readme}")


def write_text_if_missing(path: Path, content: str, preview: bool) -> None:
    if preview:
        print(f"[preview] {path}")
        return
    if path.exists():
        print(f"[exists] {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    print(f"[create] {path}")


def ensure_solution(target_root: Path, project_name: str, service_name: str | None, preview: bool) -> None:
    solution = target_root / f"{project_name}.slnx"
    if preview:
        print(f"[preview] {solution}")
        return
    if solution.exists():
        print(f"[exists] {solution}")
        return

    folders: dict[str, list[str]] = {}
    for project in _solution_projects(service_name):
        folder = str(Path(project).parent).replace("\\", "/")
        folders.setdefault(folder, []).append(project.replace("\\", "/"))

    lines = ["<Solution>"]
    for folder, projects in sorted(folders.items()):
        lines.append(f'  <Folder Name="/{folder}/">')
        for project in sorted(projects):
            lines.append(f'    <Project Path="{project}" />')
        lines.append("  </Folder>")
    lines.append("</Solution>")
    solution.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"[create] {solution}")


def ensure_dotnet_skeleton(target_root: Path, project_name: str, service_name: str | None, preview: bool) -> None:
    for relative, content in _project_files(project_name, service_name).items():
        write_text_if_missing(target_root / relative, content, preview)
    ensure_solution(target_root, project_name, service_name, preview)


def source_harness_root() -> Path:
    script = Path(__file__).resolve()
    candidates = [
        script.parents[4],
        script.parents[3] / "assets/harness",
    ]
    for candidate in candidates:
        if (candidate / ".codex/agents").exists() and (candidate / ".codex/scripts").exists():
            return candidate
    return candidates[0]


def should_skip_copy(path: Path) -> bool:
    return "__pycache__" in path.parts or path.suffix == ".pyc"


def copy_file_if_missing(source: Path, target: Path, preview: bool) -> None:
    if not source.exists():
        print(f"[skip] missing harness source: {source}")
        return
    if preview:
        print(f"[preview] {target}")
        return
    if target.exists():
        print(f"[exists] {target}")
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    print(f"[create] {target}")


def copy_dir_if_missing(source: Path, target: Path, preview: bool) -> None:
    if not source.exists():
        print(f"[skip] missing harness source: {source}")
        return
    for source_file in source.rglob("*"):
        if not source_file.is_file() or should_skip_copy(source_file):
            continue
        relative = source_file.relative_to(source)
        copy_file_if_missing(source_file, target / relative, preview)


def remove_repo_local_skills(target_root: Path, preview: bool) -> None:
    skills_dir = target_root / ".codex/skills"
    if not skills_dir.exists():
        return

    backup_root = target_root / ".codex/backups/harness-install"
    backup_dir = backup_root / "skills-backup"
    if preview:
        print(f"[preview] backup {skills_dir} -> {backup_dir}")
        print(f"[preview] remove {skills_dir}")
        return

    if backup_dir.exists():
        suffix = 2
        while (backup_root / f"skills-backup-{suffix}").exists():
            suffix += 1
        backup_dir = backup_root / f"skills-backup-{suffix}"

    backup_dir.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(skills_dir, backup_dir)
    shutil.rmtree(skills_dir)
    print(f"[backup] {skills_dir} -> {backup_dir}")
    print(f"[remove] {skills_dir}")


def optional_skill_source(source_root: Path, skill_name: str) -> Path | None:
    candidates = [
        source_root.parent / "optional-skills" / skill_name,
        source_root.parent.parent / "optional-skills" / skill_name,
    ]
    for candidate in candidates:
        if (candidate / "SKILL.md").exists():
            return candidate
    return None


def ensure_optional_caveman_skill(target_root: Path, source_root: Path, preview: bool, install_optional_skills: bool) -> None:
    script = (
        source_root / ".codex/scripts/ensure-caveman-skill.ps1"
        if preview
        else target_root / ".codex/scripts/ensure-caveman-skill.ps1"
    )
    if not script.exists():
        print(f"[skip] missing optional skill helper: {script}")
        return

    command = ["pwsh", "-NoProfile", "-File", str(script)]
    source = optional_skill_source(source_root, "caveman")
    if source:
        command.extend(["-SkillSource", str(source)])
    if install_optional_skills:
        command.append("-Apply")
        command.append("-AllowUserSkillInstall")

    try:
        subprocess.run(command, check=False)
    except OSError as exc:
        print(f"[warn] caveman optional skill check failed: {exc}")


def install_codex_harness(target_root: Path, preview: bool, install_optional_skills: bool) -> None:
    source_root = source_harness_root()
    for source_rel in HARNESS_FILES:
        copy_file_if_missing(source_root / source_rel, target_root / source_rel, preview)
    for source_rel in HARNESS_DIRS:
        copy_dir_if_missing(source_root / source_rel, target_root / source_rel, preview)
    remove_repo_local_skills(target_root, preview)
    ensure_optional_caveman_skill(target_root, source_root, preview, install_optional_skills)


def run(
    base_root: Path,
    project_name: str,
    service_name: str | None,
    preview: bool,
    no_gitkeep: bool,
    harness_only: bool,
    install_optional_skills: bool,
) -> None:
    target_root = base_root
    if preview:
        print(f"[project] {project_name}")
    if not harness_only:
        for dir_path in collect_dirs(base_root, service_name):
            if preview:
                print(f"[preview] {dir_path}")
                continue

            created = dir_path.exists()
            dir_path.mkdir(parents=True, exist_ok=True)
            if created:
                print(f"[exists] {dir_path}")
            else:
                print(f"[create] {dir_path}")

            if not no_gitkeep:
                ensure_gitkeep(dir_path)

        ensure_project_readme(target_root, preview)
        ensure_dotnet_skeleton(target_root, project_name, service_name, preview)
    install_codex_harness(target_root, preview, install_optional_skills)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Create architecture folders with variable project and service names")
    parser.add_argument("--root", default=".", help="Base path where structure is created")
    parser.add_argument("--project-name", help="Project folder name")
    parser.add_argument("--service-name", help="Optional service name")
    parser.add_argument("--preview", action="store_true", help="Print target directories only")
    parser.add_argument("--no-gitkeep", action="store_true", help="Do not create .gitkeep files")
    parser.add_argument("--harness-only", action="store_true", help="Install Codex harness files only")
    parser.add_argument("--install-optional-skills", action="store_true", help="Install optional user skills such as caveman when missing")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    root = Path(args.root).resolve()

    project_name = _normalize_name(args.project_name) if args.project_name else None
    if not project_name:
        project_name = _normalize_name(_prompt_project_name())

    service_name = _normalize_name(args.service_name) if args.service_name else None
    if service_name is None and not args.harness_only:
        prompted_service = _prompt_service_name()
        service_name = _normalize_name(prompted_service) if prompted_service else None

    if project_name == "":
        raise SystemExit("--project-name cannot be empty")
    if service_name == "":
        raise SystemExit("--service-name cannot be empty")

    run(
        root,
        project_name,
        service_name,
        preview=args.preview,
        no_gitkeep=args.no_gitkeep,
        harness_only=args.harness_only,
        install_optional_skills=args.install_optional_skills,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
