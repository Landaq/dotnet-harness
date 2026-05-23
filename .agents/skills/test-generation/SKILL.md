---
name: test-generation
description: Use this skill when generating unit, integration, API, EF Core, or Blazor tests for .NET projects.
---

# .NET Test Generation Skill

## Workflow

먼저 저장소가 xUnit, NUnit, MSTest 중 무엇을 사용하는지 확인한다. 기존 테스트 스타일, fixture, assertion library, mocking library, test naming convention을 따른다.

## Test strategy

| 대상 | 권장 방식 |
| --- | --- |
| Domain/service logic | 빠른 unit test와 명확한 edge case |
| ASP.NET Core API | `WebApplicationFactory` 기반 integration test |
| EF Core query | provider 차이를 고려한 integration test 우선 |
| Blazor component | 프로젝트가 bUnit을 사용하면 component test |
| Regression | 버그 재현 테스트를 먼저 작성한 뒤 수정 |

## Output format

테스트 제안은 test list, required fixtures, sample test code, execution command, expected failures 순서로 작성한다.

