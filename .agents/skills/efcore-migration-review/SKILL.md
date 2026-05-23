---
name: efcore-migration-review
description: Use this skill when creating, reviewing, or modifying EF Core migrations, DbContext mappings, SQL Server schema changes, and data access code.
---

# EF Core Migration Review Skill

## Workflow

마이그레이션 검토 시 모델 변경, migration Up/Down, SQL Server 실제 영향, 기존 데이터 보존, 인덱스, 제약 조건, cascade delete, nullable 변경, default value를 함께 확인한다.

## Safety rules

운영 데이터에 영향을 줄 수 있는 `dotnet ef database update`, `dotnet ef database drop`, 직접 SQL 변경은 실행하지 않는다. 필요하면 명령을 제안하되 사용자의 명시 승인을 요구한다.

## Review checklist

| 항목 | 질문 |
| --- | --- |
| Data loss | 컬럼 삭제, 타입 축소, nullable 변경이 데이터를 잃게 하는가? |
| Index | 조회 패턴에 맞는 인덱스가 있는가? 중복 인덱스는 없는가? |
| Constraint | FK, unique, check constraint가 의도와 맞는가? |
| Cascade | cascade delete가 예상치 못한 대량 삭제를 유발하지 않는가? |
| Rollback | Down migration이 안전하고 현실적인가? |
| Performance | 대형 테이블 변경 시 lock, migration duration 문제가 있는가? |

## Output format

마이그레이션 리뷰는 risk summary, blocking issues, recommended migration edits, post-deploy verification 순서로 작성한다.

