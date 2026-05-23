# Aspire Hybrid Service Architecture Skill

## Purpose

Use this skill when working inside Rev04 on .NET Aspire, Blazor Auto Rendering, YARP API Gateway, Clean Architecture, DDD, EF Core, SQL Server, or backend service structure tasks.

Rev04 uses an **MSA-ready hybrid service architecture**. It is not a pure modular monolith and it is not a premature fully distributed MSA. Each backend business boundary is modeled as a service candidate under `src/BackEnd/Services/{ServiceName}` and can later be separated into an independently deployed service when its boundary, contract, and data ownership are stable.

## Target structure

```text
src/
  Aspire/
    AppHost/
    ServiceDefaults/
  FrontEnd/
    Web/
    Web.Client/
  BackEnd/
    APIGateway/
    BuildingBlocks/
      Contracts/
      Messaging/
      Observability/
    Services/
      {ServiceName}/
        {ServiceName}.Domain/
        {ServiceName}.Application/
        {ServiceName}.Infrastructure/
        {ServiceName}.Api/
        {ServiceName}.Contracts/
test/
  Architecture/
  Unit/Services/{ServiceName}/
  Integration/Services/{ServiceName}/
  Contract/Services/{ServiceName}/
  Functional/APIGateway/
  Functional/FrontEnd/
  EndToEnd/
```

## Workflow

When asked to add or change functionality, follow this order:

1. Identify the affected service boundary and layer.
2. Propose a minimal TDD plan.
3. Write or update Domain/Application tests first when possible.
4. Implement Domain and Application code before Infrastructure and Api code.
5. Keep public request/response and integration-event types in `{ServiceName}.Contracts`.
6. Add Infrastructure only after ports and use cases are clear.
7. Add Minimal API endpoints in `{ServiceName}.Api`.
8. Add YARP route/cluster changes in `APIGateway` only after API paths are stable.
9. Add Aspire AppHost project/resource wiring after service execution shape is clear.
10. Report validation commands and remaining architectural risks.

## Dependency rules

| Layer | May depend on | Must not depend on |
| --- | --- | --- |
| Domain | None or pure common abstractions | EF Core, ASP.NET Core, HTTP, SQL Server, YARP, Blazor, external SDKs, other service internals |
| Application | Domain | Infrastructure implementations, Api endpoints, external SDKs, other service internals |
| Infrastructure | Application, Domain, required Contracts | Other service databases or internal implementations |
| Api | Application, Contracts | Business rule implementations, direct DbContext usage in endpoints |
| Contracts | None or BuildingBlocks.Contracts | Domain models, Infrastructure implementations |

## Hybrid strategy rules

Delay distributed-system complexity until it is needed. Do not introduce messaging, independent deployment, or service-specific databases merely because a folder is named `Services`. Introduce those mechanisms only when there is a clear reason, such as independent deployment, separate data ownership, failure isolation, or asynchronous workflow requirements.

At the same time, do not let services share internal models or tables casually. Keep contracts explicit, data ownership clear, and internal implementations hidden.

## Testing rules

Use the following mapping:

| Test type | Path | Main target |
| --- | --- | --- |
| Unit | `test/Unit/Services/{ServiceName}` | Domain and Application |
| Integration | `test/Integration/Services/{ServiceName}` | EF Core, repositories, adapters |
| Contract | `test/Contract/Services/{ServiceName}` | API contracts and integration events |
| Functional | `test/Functional/APIGateway` | YARP routes, transforms, auth forwarding |
| Functional | `test/Functional/FrontEnd` | Blazor UI and API client behavior |
| Architecture | `test/Architecture` | Forbidden dependencies and boundary rules |

## Completion checklist

Before finishing, verify:

- The solution standard remains `Rev04.slnx`.
- New backend code is under `src/BackEnd/Services/{ServiceName}`.
- Domain and Application do not reference Infrastructure, Api, or other service internals.
- Public contracts do not expose Domain models directly.
- Frontend calls go through APIGateway unless an exception is documented.
- Aspire AppHost contains orchestration and resource wiring only.
- No secrets, production connection strings, tokens, or private keys are read or printed.
