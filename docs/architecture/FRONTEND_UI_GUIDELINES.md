# FrontEnd UI Guidelines

이 문서는 Rev04의 Blazor FrontEnd 작업에서 사용할 UI 컴포넌트 선택 기준을 정의한다. 기준은 **MudBlazor를 기본 UI 컴포넌트 라이브러리로 사용**하고, **BI 관련 UI 또는 기능은 DevExpress Blazor 23.2.x 버전 라인에 맞춰 대비**하는 것이다.

## 1. 기본 원칙

Rev04의 프런트엔드는 `src/FrontEnd/Web`과 `src/FrontEnd/Web.Client`로 분리하며, 기본 렌더링 전략은 Blazor Web App의 Auto Rendering을 우선 검토한다. UI 컴포넌트 선택은 렌더링 위치, 브라우저 실행 가능성, 보안 경계, 라이선스 영향, 패키지 버전 정책을 함께 고려해야 한다.

| 구분 | 기준 |
| --- | --- |
| 일반 업무 UI | MudBlazor를 기본 선택지로 사용한다. |
| BI 관련 UI·기능 | DevExpress Blazor 23.2.x 기준으로 설계 가능성을 검토한다. |
| 단순 CRUD | MudBlazor를 우선 사용하며 DevExpress를 기본 도입하지 않는다. |
| 패키지 버전 | DevExpress 계열은 사용자 승인 없이 23.2.x 라인을 벗어나지 않는다. |
| 비밀 정보 | 라이선스 키, NuGet feed 인증 정보, 계정 정보는 소스와 문서 예시에 기록하지 않는다. |

## 2. MudBlazor 기본 적용 범위

MudBlazor는 Rev04의 기본 UI 컴포넌트 기준이다. FrontEnd Agent는 일반 업무 화면을 설계하거나 구현할 때 별도 사유가 없는 한 MudBlazor 컴포넌트를 먼저 검토한다.

| UI 유형 | 기본 선택 |
| --- | --- |
| 애플리케이션 레이아웃 | MudBlazor |
| 내비게이션, 메뉴, 앱바 | MudBlazor |
| 입력 폼과 검증 표시 | MudBlazor |
| 다이얼로그, 스낵바, 알림 | MudBlazor |
| 일반 테이블과 목록 | MudBlazor |
| 설정 화면과 관리 화면 | MudBlazor |
| 권한별 표시/숨김 UI | MudBlazor + 백엔드 권한 검증 |

MudBlazor 기반 구현에서도 도메인 판단은 프런트엔드 컴포넌트에 두지 않는다. 사용자의 입력 검증은 클라이언트 UX 차원의 검증과 서버 측 Application 계층 검증을 분리하며, 클라이언트 검증만으로 충분하다고 간주하지 않는다.

## 3. DevExpress Blazor 23.2 대비 범위

DevExpress Blazor는 Rev04에서 BI 성격의 UI 또는 기능을 대비하기 위한 선택지다. DevExpress 도입은 기능 요구가 명확할 때만 검토하며, 일반 UI 전반을 DevExpress로 통일하는 정책이 아니다.

| BI 후보 기능 | DevExpress 검토 사유 |
| --- | --- |
| 대시보드 | 차트, 카드, 고급 데이터 표현 요구가 클 때 검토한다. |
| 고급 데이터 그리드 | 대량 데이터, 그룹핑, 필터링, 정렬, 컬럼 커스터마이징 요구가 클 때 검토한다. |
| 피벗 성격 분석 화면 | 다차원 분석 또는 집계 중심 화면일 때 검토한다. |
| 리포팅 | 출력물, 인쇄, 문서화, 보고서 뷰어 요구가 있을 때 검토한다. |
| 차트 중심 분석 페이지 | 복수 지표 시각화와 상호작용 요구가 높을 때 검토한다. |
| 데이터 내보내기 중심 화면 | Excel/PDF 등 내보내기 요구가 핵심일 때 검토한다. |

DevExpress 관련 패키지는 사용자가 별도로 승인하지 않는 한 **23.2.x 버전 라인**을 기준으로 검토한다. 패키지 도입 전에는 목적, MudBlazor 또는 기본 Blazor 대안, 라이선스 영향, 배포 영향, Web.Client 호환성, 테스트 전략을 먼저 설명해야 한다. 실제 NuGet 패키지를 추가할 때는 루트의 `Directory.Packages.props`에 구체 버전을 중앙 관리하고, 개별 프로젝트 파일에는 필요한 `PackageReference`만 추가한다.

## 4. FrontEnd Agent 작업 체크리스트

FrontEnd Agent는 UI 변경을 제안하거나 구현할 때 다음 항목을 보고해야 한다.

| 확인 항목 | 설명 |
| --- | --- |
| 대상 프로젝트 | `src/FrontEnd/Web`, `src/FrontEnd/Web.Client` 중 변경 위치를 명시한다. |
| 컴포넌트 라이브러리 | MudBlazor 또는 DevExpress 선택 사유를 명시한다. |
| 렌더 모드 영향 | Auto Rendering, Static SSR, Interactive Server, Interactive WebAssembly 영향 여부를 확인한다. |
| 패키지 영향 | 신규 NuGet 또는 npm 패키지와 버전 정책을 설명한다. |
| API 경계 | 백엔드 호출이 `APIGateway`와 Contracts 경계를 지키는지 확인한다. |
| 보안 경계 | `Web.Client`에 비밀 정보, 서버 전용 SDK, 직접 DB 접근이 없는지 확인한다. |
| 테스트 | `test/Functional/FrontEnd` 기준의 렌더링, 폼 동작, API client interaction, 권한별 표시 테스트를 제안한다. |

## 5. 금지 사항

다음 작업은 사용자의 명시 승인 없이 수행하지 않는다.

| 금지 항목 | 이유 |
| --- | --- |
| DevExpress 23.2.x 라인 외 버전 사용 | 프로젝트 기준 버전 이탈 방지 |
| DevExpress 라이선스 키 소스 포함 | 비밀 정보 유출 방지 |
| NuGet feed 인증 정보를 저장소에 기록 | 공급망 보안 및 자격 증명 보호 |
| 단순 CRUD에 DevExpress 기본 도입 | 라이선스·복잡도 증가 방지 |
| `Web.Client`에서 서버 전용 SDK 사용 | 브라우저 실행 경계 위반 방지 |
| 클라이언트에서 직접 DB 접근 | 보안·아키텍처 경계 위반 방지 |

