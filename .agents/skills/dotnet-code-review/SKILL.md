---
name: dotnet-code-review
description: Use this skill when reviewing changed C#/.NET code for correctness, maintainability, security, performance, and test coverage.
---

# .NET Code Review Skill

## Workflow

먼저 변경된 파일, 관련 `.csproj`, 테스트 프로젝트, public API 변경 여부를 확인한다. 리뷰는 기능 정확성, 예외 처리, nullability, async/await 사용, DI lifetime, logging, 보안, 성능, 테스트 범위를 분리해 수행한다.

## Review checklist

| 영역 | 확인 사항 |
| --- | --- |
| Correctness | 요구사항 충족, 경계값, 예외 흐름, 취소 토큰 처리 |
| Maintainability | 클래스 책임, 의존성 방향, 중복, 명명, public API 안정성 |
| Async | `.Result`/`.Wait()` 사용, fire-and-forget, cancellation propagation |
| DI | Singleton/Scoped/Transient lifetime 충돌, disposable 처리 |
| Security | 입력 검증, 인증/인가, 비밀 로깅, injection 위험 |
| Performance | 불필요한 allocation, N+1 query, sync I/O, 대량 데이터 처리 |
| Tests | 단위 테스트, 통합 테스트, 회귀 테스트, 실패 케이스 |

## Output format

리뷰 결과는 severity, 파일, 근거, 권장 수정으로 작성한다. 단순 취향 문제는 “nit”으로 분리하고, 반드시 수정해야 하는 문제와 구분한다.

