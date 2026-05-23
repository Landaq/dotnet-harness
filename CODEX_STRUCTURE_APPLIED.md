# Codex/Aspire 하이브리드 서비스 구조 적용 파일 목록

현재 프로젝트에 다음 Codex 및 아키텍처 구조 파일을 적용했습니다. 기준 솔루션 파일은 **`Rev04.slnx`**이며, 백엔드 기준 구조는 **`src/BackEnd/Services/{ServiceName}` 기반 MSA-ready Hybrid Architecture**입니다.

| 상태 | 경로 | 역할 |
| --- | --- | --- |
| 완료 | `AGENTS.md` | Codex가 따를 저장소 전체 작업 지침입니다. |
| 완료 | `CODEX_SETUP.md` | Codex CLI 사용 및 첫 실행 안내입니다. |
| 완료 | `docs/architecture/PROJECT_STRUCTURE.md` | Aspire, FrontEnd, BackEnd Services, test 기준 목표 구조 설명입니다. |
| 완료 | `docs/architecture/SERVICE_TEMPLATE.md` | 새 업무 서비스를 추가할 때 따를 DDD/Clean Architecture 템플릿입니다. |
| 완료 | `docs/testing/TDD_GUIDE.md` | Red-Green-Refactor 및 서비스 기준 테스트 계층 운영 기준입니다. |
| 완료 | `.codex/rules/default.rules` | 위험 명령과 안전한 .NET 개발 명령, 하이브리드 서비스 구조 정책입니다. |
| 완료 | `.codex/agents/dotnet-architect.toml` | Aspire/DDD/Hybrid Services 구조 검토용 아키텍트 서브에이전트입니다. |
| 완료 | `.codex/agents/test-writer.toml` | TDD 및 서비스 기준 테스트 계층 설계용 서브에이전트입니다. |
| 완료 | `.agents/skills/aspire-modular-ddd/SKILL.md` | Aspire + 하이브리드 서비스 아키텍처 작업용 Codex 스킬입니다. |
| 완료 | `.codex/setup-project-structure.ps1` | 기준 폴더 골격을 생성·검증하는 PowerShell 스크립트입니다. |

다음 단계는 실제 `Rev04.slnx` 및 `.csproj` 생성입니다. 권장 순서는 `Rev04.slnx`, Aspire AppHost/ServiceDefaults, FrontEnd Web/Web.Client, BackEnd APIGateway, BackEnd BuildingBlocks, 첫 번째 업무 서비스, test 프로젝트 순입니다.
