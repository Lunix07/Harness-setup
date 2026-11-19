# Transferable Concept Map

Core ideas that show up across tools. Use these to name the general principle behind a specific problem and to connect it to design decisions. Each entry: the concept, where it shows up, and why it matters when designing systems.

## Contents
1. Systems & OS
2. Networking
3. Concurrency & async
4. Data & storage
5. Distributed systems
6. Delivery & infrastructure
7. Frontend & web

## 1. Systems & OS
- **Processes, isolation, namespaces** — Linux processes, containers (namespaces + cgroups), VMs, sandboxes. *Design:* the isolation boundary decides what can fail together and what can share resources.
- **Everything is a file / file descriptors** — sockets, pipes, devices, `/proc`. *Design:* explains "too many open files", connection limits, and why resource limits must be planned.
- **Permissions & least privilege** — Unix users/groups, IAM policies, service accounts, DB roles. *Design:* blast radius; every component should only be able to do what it needs.
- **Environment & configuration** — env vars, config files, secrets, 12-factor config. *Design:* separating config from code is what makes the same artifact deployable everywhere.

## 2. Networking
- **Layers & encapsulation** — TCP/IP model; HTTP over TLS over TCP over IP. *Design:* knowing which layer a problem lives at is half of debugging; load balancers operate at L4 or L7 with very different capabilities.
- **Name resolution & indirection** — DNS, service discovery, Kubernetes Services. *Design:* indirection enables moving/scaling things without changing clients, at the cost of caching/TTL staleness.
- **Connections are expensive** — TCP + TLS handshakes, connection pooling, keep-alive. *Design:* pooling and reuse drive DB and HTTP client setup; serverless functions struggle here.
- **Timeouts and retries** — every network call can hang or fail. *Design:* every remote call needs a timeout; retries need backoff + idempotency.

## 3. Concurrency & async
- **Event loop vs threads** — JS/Deno event loop, Python asyncio, thread pools. *Design:* CPU-bound work blocks an event loop; choose the model by workload shape.
- **Race conditions & shared state** — check-then-act bugs, lost updates. *Design:* push shared state to something that gives atomicity (DB transactions, atomic ops, locks).
- **Backpressure** — queues filling up, streams, rate limits. *Design:* a fast producer will eventually overwhelm a slow consumer unless the system can push back.
- **Ordering** — promises resolving out of order, message queues without ordering guarantees. *Design:* decide explicitly where order matters and pay for it only there.

## 4. Data & storage
- **Indexes & access patterns** — B-trees, scans vs lookups, query planners. *Design:* schema and indexes follow the queries you'll actually run.
- **Transactions & isolation levels** — ACID, dirty/phantom reads, locking. *Design:* determines what anomalies your app must tolerate or prevent.
- **Caching & staleness** — TTLs, invalidation, CDN, in-memory caches. *Design:* per piece of data, decide how stale is acceptable.
- **Schema evolution & migrations** — backward-compatible changes, expand/contract. *Design:* zero-downtime deploys require old and new code to work with the same schema.

## 5. Distributed systems
- **Idempotency** — safe retries, idempotency keys, PUT vs POST. *Design:* the foundation of reliable queues, payments, and webhooks.
- **Consistency trade-offs** — eventual consistency, replication lag, CAP intuition. *Design:* choose consistency per feature rather than globally.
- **Failure is normal** — partial failures, health checks, circuit breakers. *Design:* design for degraded modes, not only for the happy path.
- **Statelessness** — sessions in a store, not in memory. *Design:* stateless services scale horizontally; state concentrates in a few deliberate places.
- **Observability** — logs, metrics, traces, correlation IDs. *Design:* you can only fix what you can see; plan it before production.

## 6. Delivery & infrastructure
- **Immutable artifacts** — build once, deploy the same image everywhere. *Design:* removes "works on my machine" and makes rollbacks trivial.
- **Declarative vs imperative** — Terraform, Kubernetes manifests vs scripts. *Design:* declare desired state and let a reconciler converge; understand state files and drift.
- **Reproducible environments** — CI runners start clean, lockfiles, pinned versions. *Design:* anything implicit on a dev machine becomes a CI failure.
- **Blast radius & rollout** — canary, blue/green, feature flags. *Design:* release strategies limit how much breaks when something goes wrong.

## 7. Frontend & web
- **Rendering location** — SSR, CSR, static, islands (Fresh renders on the server and only hydrates interactive islands). *Design:* trade-off between JS shipped, time-to-interactive, and server load.
- **The browser security model** — same-origin policy, CORS, cookies (SameSite, HttpOnly). *Design:* CORS errors are the browser protecting users; auth design must respect it.
- **HTTP semantics** — methods, status codes, caching headers. *Design:* using HTTP correctly gets you caching, retries, and tooling compatibility for free.
