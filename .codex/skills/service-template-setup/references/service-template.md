# Service Template Reference

Base template path: `src/BackEnd/Services/{ServiceName}` with:

- `{ServiceName}.Domain`: Aggregates, Entities, ValueObjects, Events, Repositories
- `{ServiceName}.Application`: Abstractions, UseCases/Commands, UseCases/Queries, DTOs, Validators
- `{ServiceName}.Infrastructure`: Persistence configurations/migrations, Repositories, Integrations
- `{ServiceName}.Api`: Endpoints, Mapping
- `{ServiceName}.Contracts`: Requests, Responses, IntegrationEvents

Service creation flow:

- Define boundary and contract scope first.
- Write unit tests before infrastructure and Api implementations.
- Keep Gateway and AppHost linkage as a separate step after core logic stabilizes.

Dependency guard:

- Domain/Application should not depend on Infrastructure/Api concrete implementations.
- Contracts should not depend on Domain internals.
