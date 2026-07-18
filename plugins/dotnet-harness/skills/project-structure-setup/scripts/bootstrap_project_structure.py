#!/usr/bin/env python3
"""Create folder skeleton from PROJECT_STRUCTURE.md-like architecture rules."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import unicodedata
from pathlib import Path
from xml.sax.saxutils import escape

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


def _package_versions_manifest() -> Path:
    return Path(__file__).resolve().parents[1] / "references" / "package-versions.json"


def _load_versions_manifest() -> dict[str, object]:
    manifest = _package_versions_manifest()
    with manifest.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise SystemExit(f"Invalid version manifest: {manifest}")
    return data


def _manifest_version(section: str, name: str) -> str:
    manifest = _package_versions_manifest()
    entries = _load_versions_manifest().get(section)
    if not isinstance(entries, dict):
        raise SystemExit(f"Invalid {section} section in version manifest: {manifest}")
    version = entries.get(name)
    if not isinstance(version, str) or not version:
        raise SystemExit(f"Missing {section} version for {name} in {manifest}")
    return version


def _package_versions_props() -> str:
    manifest = _package_versions_manifest()
    data = _load_versions_manifest()

    packages = data.get("packages")
    if not isinstance(packages, dict) or not packages:
        raise SystemExit(f"Invalid package version manifest: {manifest}")

    lines = [
        "<Project>",
        "  <PropertyGroup>",
        "    <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>",
        "  </PropertyGroup>",
        "  <ItemGroup>",
    ]
    for name, version in packages.items():
        if not isinstance(name, str) or not isinstance(version, str) or not name or not version:
            raise SystemExit(f"Invalid package version entry in {manifest}: {name!r}")
        lines.append(f'    <PackageVersion Include="{escape(name)}" Version="{escape(version)}" />')
    lines.extend(["  </ItemGroup>", "</Project>", ""])
    return "\n".join(lines)


def _aspire_resource_name(value: str, suffix: str = "") -> str:
    normalized = re.sub(r"[^A-Za-z0-9-]+", "-", value)
    normalized = re.sub(r"-+", "-", normalized).strip("-")
    if not normalized or not normalized[0].isalpha() or not normalized[0].isascii():
        normalized = f"app-{normalized}" if normalized else "app"
    max_base_length = 64 - len(suffix)
    normalized = normalized[:max_base_length].rstrip("-") or "app"
    return f"{normalized}{suffix}"


def _project_files(project_name: str, service_name: str | None) -> dict[str, str]:
    database_resource_name = _aspire_resource_name(project_name or "DotnetHarness", suffix="Db")
    aspire_sdk_version = _manifest_version("sdks", "Aspire.AppHost.Sdk")
    service = service_name or "Sample"
    service_var = f"{service[:1].lower()}{service[1:]}Api"
    service_slug = _aspire_resource_name(service).lower()
    service_resource_name = _aspire_resource_name(service, suffix="-api").lower()
    service_apphost_reference = (
        f'    <ProjectReference Include="..\\..\\BackEnd\\Services\\{service}\\{service}.Api\\{service}.Api.csproj" />\n'
        if service_name
        else ""
    )
    service_apphost_registration = (
        f"""\nvar {service_var} = builder.AddProject<Projects.{service}_Api>("{service_resource_name}")
    .WithReference(sql)
    .WithReference(redis);

apiGateway.WithReference({service_var});
"""
        if service_name
        else ""
    )
    reverse_proxy_config = (
        f"""{{
  "ReverseProxy": {{
    "Routes": {{
      "{service_slug}-api-route": {{
        "ClusterId": "{service_slug}-api-cluster",
        "Match": {{
          "Path": "/api/{service_slug}/{{**catch-all}}"
        }}
      }}
    }},
    "Clusters": {{
      "{service_slug}-api-cluster": {{
        "Destinations": {{
          "primary": {{
            "Address": "https+http://{service_resource_name}"
          }}
        }}
      }}
    }}
  }}
}}
"""
        if service_name
        else """{
  "ReverseProxy": {
    "Routes": {},
    "Clusters": {}
  }
}
"""
    )
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
*.zsh text eol=lf
*.sh text eol=lf
""",
        ".codex/harness-config.json": """{
  "ui": {
    "defaultLibrary": "MudBlazor",
    "biLibrary": "DevExpress",
    "devExpressVersion": "23.2.x"
  }
}
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
    <NuGetAudit>false</NuGetAudit>
  </PropertyGroup>
</Project>
""",
        "Directory.Packages.props": _package_versions_props(),
        "src/Aspire/AppHost/AppHost.csproj": f"""<Project Sdk="Microsoft.NET.Sdk">
  <Sdk Name="Aspire.AppHost.Sdk" Version="{escape(aspire_sdk_version)}" />
  <PropertyGroup>
    <OutputType>Exe</OutputType>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Aspire.Hosting.AppHost" />
    <PackageReference Include="Aspire.Hosting.SqlServer" />
    <PackageReference Include="Aspire.Hosting.Redis" />
    <ProjectReference Include="..\\..\\BackEnd\\APIGateway\\APIGateway.csproj" />
    <ProjectReference Include="..\\..\\FrontEnd\\Web\\Web.csproj" />
""" + service_apphost_reference + """  </ItemGroup>
</Project>
""",
        "src/Aspire/AppHost/Program.cs": f"""var builder = DistributedApplication.CreateBuilder(args);

var sql = builder.AddSqlServer("sql").AddDatabase("{database_resource_name}");
var redis = builder.AddRedis("redis");

var apiGateway = builder.AddProject<Projects.APIGateway>("api-gateway")
    .WithReference(sql)
    .WithReference(redis);
""" + service_apphost_registration + """

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

public partial class Program
{
}
""",
        "src/BackEnd/APIGateway/appsettings.json": reverse_proxy_config,
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
    .AddInteractiveWebAssemblyRenderMode()
    .AddAdditionalAssemblies(typeof(Web.Client.ClientAssemblyMarker).Assembly);

app.Run();
""",
        "src/FrontEnd/Web/App.razor": """<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <base href="/" />
    <title>Dotnet Harness</title>
    <link href="_content/MudBlazor/MudBlazor.min.css" rel="stylesheet" />
    <HeadOutlet @rendermode="InteractiveAuto" />
</head>
<body>
    <Web.Client.Routes @rendermode="InteractiveAuto" />
    <script src="_framework/blazor.web.js"></script>
    <script src="_content/MudBlazor/MudBlazor.min.js"></script>
</body>
</html>
""",
        "src/FrontEnd/Web/_Imports.razor": """@using Microsoft.AspNetCore.Components.Web
@using static Microsoft.AspNetCore.Components.Web.RenderMode
""",
        "src/FrontEnd/Web.Client/Routes.razor": """<Router AppAssembly="typeof(Program).Assembly">
    <Found Context="routeData">
        <RouteView RouteData="routeData" DefaultLayout="typeof(MainLayout)" />
    </Found>
</Router>
""",
        "src/FrontEnd/Web.Client/Layout/MainLayout.razor": """@inherits LayoutComponentBase

<MudProviders />

<MudLayout>
    <MudMainContent Class="pa-4">
        @Body
    </MudMainContent>
</MudLayout>
""",
        "src/FrontEnd/Web.Client/Layout/MudProviders.razor": """<MudThemeProvider />
<MudPopoverProvider />
<MudDialogProvider />
<MudSnackbarProvider />
""",
        "src/FrontEnd/Web.Client/Pages/Home.razor": """@page "/"

<MudText Typo="Typo.h4">Dotnet Harness</MudText>
<MudText>Blazor Auto Rendering + MudBlazor baseline.</MudText>
<MudLink Href="/interactive">Open the interactive client page</MudLink>
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
@using Microsoft.AspNetCore.Components.Routing
@using MudBlazor
@using Web.Client.Layout
@using static Microsoft.AspNetCore.Components.Web.RenderMode
""",
        "src/FrontEnd/Web.Client/ClientAssemblyMarker.cs": """namespace Web.Client;

public static class ClientAssemblyMarker
{
}
""",
        "src/FrontEnd/Web.Client/Pages/Interactive.razor": """@page "/interactive"

<PageTitle>Interactive</PageTitle>

<MudText Typo="Typo.h4">Interactive Auto</MudText>
<MudText>Count: @count</MudText>
<MudButton Variant="Variant.Filled" Color="Color.Primary" OnClick="Increment">
    Increment
</MudButton>

@code {
    private int count;

    private void Increment()
    {
        count++;
    }
}
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
        f"src/BackEnd/Services/{service}/{service}.Application/AssemblyMarker.cs": f"""namespace {service}.Application;

public static class AssemblyMarker
{{
}}
""",
        f"src/BackEnd/Services/{service}/{service}.Infrastructure/{service}.Infrastructure.csproj": f"""<Project Sdk="Microsoft.NET.Sdk">
  <ItemGroup>
    <PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" />
    <PackageReference Include="StackExchange.Redis" />
    <ProjectReference Include="..\\{service}.Application\\{service}.Application.csproj" />
  </ItemGroup>
</Project>
""",
        f"src/BackEnd/Services/{service}/{service}.Infrastructure/AssemblyMarker.cs": f"""namespace {service}.Infrastructure;

public static class AssemblyMarker
{{
}}
""",
        f"src/BackEnd/Services/{service}/{service}.Api/{service}.Api.csproj": f"""<Project Sdk="Microsoft.NET.Sdk.Web">
  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.OpenApi" />
    <PackageReference Include="Scalar.AspNetCore" />
    <ProjectReference Include="..\\..\\..\\..\\Aspire\\ServiceDefaults\\ServiceDefaults.csproj" />
    <ProjectReference Include="..\\{service}.Application\\{service}.Application.csproj" />
    <ProjectReference Include="..\\{service}.Infrastructure\\{service}.Infrastructure.csproj" />
  </ItemGroup>
</Project>
""",
        f"src/BackEnd/Services/{service}/{service}.Api/Program.cs": f"""using Scalar.AspNetCore;
using ServiceDefaults;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();
builder.Services.AddOpenApi();

var app = builder.Build();

app.MapOpenApi();
app.MapScalarApiReference();
app.MapDefaultEndpoints();
app.MapGet("/api/{service.lower()}/health", () => Results.Ok(new {{ service = "{service}", status = "ok" }}));

app.Run();
""",
        f"src/BackEnd/Services/{service}/{service}.Contracts/{service}.Contracts.csproj": """<Project Sdk="Microsoft.NET.Sdk" />
""",
        f"src/BackEnd/Services/{service}/{service}.Contracts/AssemblyMarker.cs": f"""namespace {service}.Contracts;

public static class AssemblyMarker
{{
}}
""",
        "test/Unit/Unit.Tests.csproj": """<Project Sdk="Microsoft.NET.Sdk">
  <ItemGroup>
    <Compile Remove="Services/**/*.cs" />
    <PackageReference Include="Microsoft.NET.Test.Sdk" />
    <PackageReference Include="xunit" />
    <PackageReference Include="xunit.runner.visualstudio" />
    <PackageReference Include="FluentAssertions" />
    <PackageReference Include="coverlet.collector" />
    <ProjectReference Include="..\\..\\src\\BackEnd\\BuildingBlocks\\Application\\Application.csproj" />
  </ItemGroup>
</Project>
""",
        "test/Unit/BaselineTests.cs": """using BuildingBlocks.Application.Mediator;
using FluentAssertions;
using Xunit;

namespace Unit;

public sealed class BaselineTests
{
    [Fact]
    public void Mediator_contract_exposes_request_and_dispatcher_abstractions()
    {
        typeof(IRequest<>).IsInterface.Should().BeTrue();
        typeof(IRequestDispatcher).GetMethod(nameof(IRequestDispatcher.Send)).Should().NotBeNull();
    }
}
""",
        "test/Architecture/Architecture.Tests.csproj": """<Project Sdk="Microsoft.NET.Sdk">
  <ItemGroup>
    <PackageReference Include="Microsoft.NET.Test.Sdk" />
    <PackageReference Include="xunit" />
    <PackageReference Include="xunit.runner.visualstudio" />
    <PackageReference Include="FluentAssertions" />
    <PackageReference Include="coverlet.collector" />
    <ProjectReference Include="..\\..\\src\\BackEnd\\BuildingBlocks\\Application\\Application.csproj" />
  </ItemGroup>
</Project>
""",
        "test/Architecture/BaselineArchitectureTests.cs": """using BuildingBlocks.Application.Mediator;
using FluentAssertions;
using Xunit;

namespace Architecture;

public sealed class BaselineArchitectureTests
{
    [Fact]
    public void Application_building_block_does_not_reference_persistence()
    {
        var references = typeof(IRequest<>).Assembly
            .GetReferencedAssemblies()
            .Select(assembly => assembly.Name);

        references.Should().NotContain("Persistence");
    }
}
""",
        "test/Functional/APIGateway/APIGateway.FunctionalTests.csproj": """<Project Sdk="Microsoft.NET.Sdk">
  <ItemGroup>
    <PackageReference Include="Microsoft.NET.Test.Sdk" />
    <PackageReference Include="Microsoft.AspNetCore.Mvc.Testing" />
    <PackageReference Include="xunit" />
    <PackageReference Include="xunit.runner.visualstudio" />
    <PackageReference Include="FluentAssertions" />
    <PackageReference Include="coverlet.collector" />
    <ProjectReference Include="..\\..\\..\\src\\BackEnd\\APIGateway\\APIGateway.csproj" />
  </ItemGroup>
</Project>
""",
        "test/Functional/APIGateway/APIGatewayBaselineTests.cs": """using System.Net;
using Xunit;
using Microsoft.AspNetCore.Mvc.Testing;

namespace Functional.APIGateway;

public sealed class APIGatewayBaselineTests : IClassFixture<WebApplicationFactory<global::Program>>
{
    private readonly HttpClient _client;

    public APIGatewayBaselineTests(WebApplicationFactory<global::Program> factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task Health_endpoint_starts_and_returns_success()
    {
        var response = await _client.GetAsync("/api/health");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }
}
""",
        f"test/Unit/Services/{service}/{service}.UnitTests.csproj": f"""<Project Sdk="Microsoft.NET.Sdk">
  <ItemGroup>
    <PackageReference Include="Microsoft.NET.Test.Sdk" />
    <PackageReference Include="xunit" />
    <PackageReference Include="xunit.runner.visualstudio" />
    <ProjectReference Include="..\\..\\..\\..\\src\\BackEnd\\Services\\{service}\\{service}.Application\\{service}.Application.csproj" />
  </ItemGroup>
</Project>
""",
        f"test/Unit/Services/{service}/ApplicationBaselineTests.cs": f"""using Xunit;

namespace Unit.Services.{service};

public sealed class ApplicationBaselineTests
{{
    [Fact]
    public void Application_assembly_is_loadable()
    {{
        Assert.NotNull(typeof(global::{service}.Application.AssemblyMarker).Assembly);
    }}
}}
""",
        f"test/Integration/Services/{service}/{service}.IntegrationTests.csproj": f"""<Project Sdk="Microsoft.NET.Sdk">
  <ItemGroup>
    <PackageReference Include="Microsoft.NET.Test.Sdk" />
    <PackageReference Include="xunit" />
    <PackageReference Include="xunit.runner.visualstudio" />
    <ProjectReference Include="..\\..\\..\\..\\src\\BackEnd\\Services\\{service}\\{service}.Infrastructure\\{service}.Infrastructure.csproj" />
  </ItemGroup>
</Project>
""",
        f"test/Integration/Services/{service}/InfrastructureBaselineTests.cs": f"""using Xunit;

namespace Integration.Services.{service};

public sealed class InfrastructureBaselineTests
{{
    [Fact]
    public void Infrastructure_assembly_is_loadable()
    {{
        Assert.NotNull(typeof(global::{service}.Infrastructure.AssemblyMarker).Assembly);
    }}
}}
""",
        f"test/Contract/Services/{service}/{service}.ContractTests.csproj": f"""<Project Sdk="Microsoft.NET.Sdk">
  <ItemGroup>
    <PackageReference Include="Microsoft.NET.Test.Sdk" />
    <PackageReference Include="xunit" />
    <PackageReference Include="xunit.runner.visualstudio" />
    <ProjectReference Include="..\\..\\..\\..\\src\\BackEnd\\Services\\{service}\\{service}.Contracts\\{service}.Contracts.csproj" />
  </ItemGroup>
</Project>
""",
        f"test/Contract/Services/{service}/ContractsBaselineTests.cs": f"""using Xunit;

namespace Contract.Services.{service};

public sealed class ContractsBaselineTests
{{
    [Fact]
    public void Contracts_assembly_is_loadable()
    {{
        Assert.NotNull(typeof(global::{service}.Contracts.AssemblyMarker).Assembly);
    }}
}}
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
        "test/Architecture/Architecture.Tests.csproj",
        "test/Unit/Unit.Tests.csproj",
        "test/Functional/APIGateway/APIGateway.FunctionalTests.csproj",
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
                f"test/Unit/Services/{service}/{service}.UnitTests.csproj",
                f"test/Integration/Services/{service}/{service}.IntegrationTests.csproj",
                f"test/Contract/Services/{service}/{service}.ContractTests.csproj",
            ]
        )
    return projects

HARNESS_DIRS = [
    ".codex/agent-categories",
    ".codex/agents",
    ".codex/scripts",
]

HARNESS_FILES = [
    "AGENTS.md",
]

CSHARP_IDENTIFIER = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
MAX_PROJECT_NAME_LENGTH = 120
MAX_SERVICE_NAME_LENGTH = 64
INVALID_NAME_CHARACTERS = set('<>:"/\\|?*\'')
WINDOWS_RESERVED_NAMES = {
    "CON",
    "PRN",
    "AUX",
    "NUL",
    *(f"COM{index}" for index in range(1, 10)),
    *(f"LPT{index}" for index in range(1, 10)),
}


def _normalize_name(value: str) -> str:
    return value.strip().replace(" ", "")


def _validate_common_name(value: str, option: str) -> None:
    if not value:
        raise SystemExit(f"{option} cannot be empty")
    if ".." in value:
        raise SystemExit(f"{option} cannot contain '..'")
    if value.endswith("."):
        raise SystemExit(f"{option} cannot end with '.'")
    if value.split(".", maxsplit=1)[0].upper() in WINDOWS_RESERVED_NAMES:
        raise SystemExit(f"{option} is reserved by Windows")
    if any(character in INVALID_NAME_CHARACTERS for character in value):
        raise SystemExit(f"{option} contains a path separator, quote, or invalid filename character")
    if any(unicodedata.category(character).startswith("C") for character in value):
        raise SystemExit(f"{option} cannot contain control or formatting characters")


def _validate_names(project_name: str, service_name: str | None) -> None:
    _validate_common_name(project_name, "--project-name")
    if len(project_name) > MAX_PROJECT_NAME_LENGTH:
        raise SystemExit(f"--project-name cannot exceed {MAX_PROJECT_NAME_LENGTH} characters")
    if service_name is None:
        return
    _validate_common_name(service_name, "--service-name")
    if len(service_name) > MAX_SERVICE_NAME_LENGTH:
        raise SystemExit(f"--service-name cannot exceed {MAX_SERVICE_NAME_LENGTH} characters")
    if not CSHARP_IDENTIFIER.fullmatch(service_name):
        raise SystemExit(
            "--service-name must be a C# identifier using ASCII letters, digits, or underscores "
            "and cannot start with a digit"
        )


def resolve_and_validate_options(
    target_root: Path,
    project_name: str | None,
    service_name: str | None,
    no_service: bool,
    harness_only: bool,
) -> tuple[str, str | None]:
    resolved_project = _normalize_name(project_name) if project_name else None
    if harness_only and not resolved_project:
        resolved_project = "HarnessOnly"
    if not resolved_project:
        resolved_project = _normalize_name(_prompt_project_name())

    resolved_service = _normalize_name(service_name) if service_name else None
    if no_service:
        resolved_service = None
    elif resolved_service is None and not harness_only:
        prompted_service = _prompt_service_name()
        resolved_service = _normalize_name(prompted_service) if prompted_service else None

    _validate_names(resolved_project, resolved_service)
    _validate_existing_scaffold(target_root, resolved_service, harness_only)
    return resolved_project, resolved_service


def _validate_existing_scaffold(target_root: Path, service_name: str | None, harness_only: bool) -> None:
    if harness_only or service_name is None:
        return

    apphost_project = target_root / "src/Aspire/AppHost/AppHost.csproj"
    service_project = (
        target_root
        / "src/BackEnd/Services"
        / service_name
        / f"{service_name}.Api"
        / f"{service_name}.Api.csproj"
    )
    if apphost_project.exists() and not service_project.exists():
        raise SystemExit(
            "Cannot add a service to an existing scaffold because generated AppHost, gateway, and solution "
            "files are intentionally not overwritten. Create the service through the task workflow instead."
        )


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
        if all(
            (candidate / relative).exists()
            for relative in (
                ".codex/agent-categories",
                ".codex/agents",
                ".codex/scripts",
            )
        ):
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


def install_codex_harness(target_root: Path, preview: bool) -> None:
    source_root = source_harness_root()
    for source_rel in HARNESS_FILES:
        copy_file_if_missing(source_root / source_rel, target_root / source_rel, preview)
    for source_rel in HARNESS_DIRS:
        copy_dir_if_missing(source_root / source_rel, target_root / source_rel, preview)
    remove_repo_local_skills(target_root, preview)


def run(
    base_root: Path,
    project_name: str,
    service_name: str | None,
    preview: bool,
    no_gitkeep: bool,
    harness_only: bool,
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
    install_codex_harness(target_root, preview)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Create architecture folders with variable project and service names")
    parser.add_argument("--root", default=".", help="Base path where structure is created")
    parser.add_argument("--project-name", help="Project folder name")
    parser.add_argument("--service-name", help="Optional service name")
    parser.add_argument("--no-service", action="store_true", help="Skip service scaffold without prompting")
    parser.add_argument("--preview", action="store_true", help="Print target directories only")
    parser.add_argument("--no-gitkeep", action="store_true", help="Do not create .gitkeep files")
    parser.add_argument("--harness-only", action="store_true", help="Install Codex harness files only")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    root = Path(args.root).resolve()

    project_name, service_name = resolve_and_validate_options(
        root,
        args.project_name,
        args.service_name,
        args.no_service,
        args.harness_only,
    )

    run(
        root,
        project_name,
        service_name,
        preview=args.preview,
        no_gitkeep=args.no_gitkeep,
        harness_only=args.harness_only,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
