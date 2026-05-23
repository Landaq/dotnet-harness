---
name: aspnetcore-api-design
description: Use this skill when designing or reviewing ASP.NET Core Controllers, Minimal APIs, middleware, OpenAPI contracts, and endpoint behavior.
---

# ASP.NET Core API Design Skill

## Workflow

API 변경 시 라우트, HTTP method, request/response DTO, validation, status code, ProblemDetails, 인증/인가 정책, OpenAPI 문서화를 함께 검토한다. 기존 프로젝트가 Controller 패턴인지 Minimal API 패턴인지 확인하고, 혼합이 필요한 경우 일관성 있는 기준을 제시한다.

## Minimal API guidance

엔드포인트는 기능 단위 extension method로 그룹화하고, `MapGroup`을 사용해 공통 prefix와 authorization policy를 명확히 한다. 요청 DTO는 endpoint 내부 모델과 persistence entity를 직접 공유하지 않도록 한다.

## Output format

API 설계 결과는 endpoint table, DTO 설계, validation policy, status code matrix, test cases 순서로 정리한다.

