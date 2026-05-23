---
name: yarp-gateway-review
description: Use this skill when designing or reviewing YARP reverse proxy routes, clusters, transforms, authentication forwarding, timeouts, and health checks.
---

# YARP Gateway Review Skill

## Workflow

YARP 변경 시 route match, cluster destination, transforms, request/response headers, authorization policy, CORS, timeout, retry, health check, service discovery를 함께 검토한다.

## Security focus

외부 공개 라우트와 내부 서비스 라우트가 섞이지 않도록 한다. Host header, forwarded headers, path transform, auth token forwarding 정책을 명확히 검토한다.

## Output format

YARP 리뷰는 routing table, security notes, reliability notes, observability notes, test plan 순서로 작성한다.

