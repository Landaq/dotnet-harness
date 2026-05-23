---
name: blazor-wasm-review
description: Use this skill when reviewing Blazor WebAssembly components, state management, API clients, authentication flow, JS interop, and rendering performance.
---

# Blazor WebAssembly Review Skill

## Workflow

컴포넌트 변경 시 렌더링 조건, state ownership, cascading parameter, event callback, async lifecycle method, cancellation, API client, auth token handling을 확인한다.

## Review focus

비즈니스 로직이 `.razor` 파일에 과도하게 들어가 있으면 service 또는 view model로 분리하는 방안을 제안한다. JS interop은 nullability, disposal, browser compatibility, error handling을 검토한다.

## Output format

리뷰 결과는 component behavior, state flow, API interaction, performance, test suggestions로 나누어 제시한다.

