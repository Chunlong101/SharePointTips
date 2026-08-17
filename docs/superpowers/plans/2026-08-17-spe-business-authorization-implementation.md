# SharePoint Embedded Business Authorization Demo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and locally verify an ASP.NET Core 9 Razor Pages demo that authorizes 21Vianet SharePoint Embedded access by tenant, Entra group, source location, and business role while comparing delegated and app-only access.

**Architecture:** A server-rendered confidential client uses Microsoft.Identity.Web for China-cloud OIDC and delegated token acquisition. Small services independently parse identity claims, resolve group membership, evaluate source location, make business authorization decisions, and call SPE Graph endpoints; Razor Pages consume those interfaces without accepting a client-supplied container ID.

**Tech Stack:** .NET 9, ASP.NET Core Razor Pages, Microsoft.Identity.Web, MSAL, HttpClient, xUnit, FluentAssertions, PowerShell 7, Microsoft Graph China, SharePoint Online Management Shell.

## Global Constraints

- Target `net9.0`, matching installed SDK `9.0.317`.
- Use China authority `https://login.chinacloudapi.cn` and Graph root `https://microsoftgraph.chinacloudapi.cn`.
- Existing app ID is `84ddb0d9-4d5f-4b0e-80b4-b3530e345f9b`; do not commit tenant ID, group IDs, container ID, password, secret, or token.
- Client Secret is read only from .NET User Secrets or App Service settings.
- Authorization fails closed for missing claims, incomplete group resolution, unknown location, missing role, or invalid operation.
- Development location overrides work only in `Development`, when explicitly enabled, and for loopback requests; Production ignores them.
- Container ID is server configuration only and never accepted from a request.
- Maximum simple upload size defaults to 4 MB; reject path traversal, control characters, and invalid file names.
- Scripts make no tenant changes unless `-Apply` is explicitly supplied.
- No online tenant behavior may be described as verified until the user runs the documented tenant tests.

---

## File Structure

- `SharePoint Embedded aka SPE/SPEBusinessAuthorizationDemo/global.json`: pins .NET 9 SDK feature band.
- `SharePoint Embedded aka SPE/SPEBusinessAuthorizationDemo/SPEBusinessAuthorizationDemo.sln`: solution root.
- `src/SpeAuthorizationDemo`: web application and domain services.
- `tests/SpeAuthorizationDemo.Tests`: unit tests for all fail-closed rules and Graph request boundaries.
- `scripts/Discover-SpeEnvironment.ps1`: read-only tenant/app/container discovery.
- `scripts/Prepare-SpeTestIdentities.ps1`: explicit-apply test identity and group provisioning.
- `README.md`: app registration, configuration, run, Azure China deployment, validation matrix, troubleshooting, and rollback.

### Task 1: Scaffold the solution and secure configuration contract

**Files:**
- Create: `SharePoint Embedded aka SPE/SPEBusinessAuthorizationDemo/global.json`
- Create: `SharePoint Embedded aka SPE/SPEBusinessAuthorizationDemo/SPEBusinessAuthorizationDemo.sln`
- Create: `SharePoint Embedded aka SPE/SPEBusinessAuthorizationDemo/src/SpeAuthorizationDemo/SpeAuthorizationDemo.csproj`
- Create: `SharePoint Embedded aka SPE/SPEBusinessAuthorizationDemo/src/SpeAuthorizationDemo/appsettings.json`
- Create: `SharePoint Embedded aka SPE/SPEBusinessAuthorizationDemo/src/SpeAuthorizationDemo/appsettings.Local.example.json`
- Create: `SharePoint Embedded aka SPE/SPEBusinessAuthorizationDemo/tests/SpeAuthorizationDemo.Tests/SpeAuthorizationDemo.Tests.csproj`
- Modify: `.gitignore`

**Interfaces:**
- Produces option types `AzureAdOptions`, `SpeOptions`, `AuthorizationPolicyOptions`, and `LocationPolicyOptions`, all validated at startup.

- [ ] Create a Razor Pages project and xUnit project targeting `net9.0`, add both to the solution, and add project references.
- [ ] Add packages `Microsoft.Identity.Web`, `Microsoft.Identity.Web.UI`, `Microsoft.Identity.Client`, and test packages `FluentAssertions`, `Microsoft.NET.Test.Sdk`, `xunit`, `xunit.runner.visualstudio`.
- [ ] Add option records with required TenantId, ClientId, ContainerId, role group IDs, Graph root, upload limit, trusted proxy/network and allowed CIDR fields.
- [ ] Add configuration validation tests that reject empty TenantId, ContainerId, invalid GUID group IDs, non-China Graph root, and upload sizes above 4 MB.
- [ ] Run `dotnet test SPEBusinessAuthorizationDemo.sln`; expected initial configuration tests pass.
- [ ] Add local settings and user-secret artifacts to `.gitignore`; run `git check-ignore` to prove they are ignored.
- [ ] Commit as `feat: scaffold SPE authorization demo`.

### Task 2: Implement identity and group membership resolution

**Files:**
- Create: `src/SpeAuthorizationDemo/Authentication/UserIdentity.cs`
- Create: `src/SpeAuthorizationDemo/Authentication/IUserIdentityReader.cs`
- Create: `src/SpeAuthorizationDemo/Authentication/ClaimsUserIdentityReader.cs`
- Create: `src/SpeAuthorizationDemo/Authorization/IGroupMembershipResolver.cs`
- Create: `src/SpeAuthorizationDemo/Authorization/TokenGroupMembershipResolver.cs`
- Create: `src/SpeAuthorizationDemo/Authorization/GraphGroupMembershipResolver.cs`
- Create: `src/SpeAuthorizationDemo/Authorization/CompositeGroupMembershipResolver.cs`
- Test: `tests/SpeAuthorizationDemo.Tests/Authentication/ClaimsUserIdentityReaderTests.cs`
- Test: `tests/SpeAuthorizationDemo.Tests/Authorization/GroupMembershipResolverTests.cs`

**Interfaces:**
- Produces `UserIdentity(TenantId, ObjectId, DisplayName, GroupIds, HasGroupOverage)`.
- Produces `Task<GroupResolutionResult> ResolveAsync(ClaimsPrincipal user, IReadOnlySet<Guid> relevantGroupIds, CancellationToken cancellationToken)`.

- [ ] Write tests for valid `tid`/`oid`/`groups`, missing claims, `_claim_names` group overage, malformed GUIDs, direct token match, fallback match, and fallback failure.
- [ ] Run only identity/group tests and confirm they fail because implementations do not exist.
- [ ] Implement strict claim parsing; malformed or absent `tid`/`oid` returns a failed identity result rather than guessing.
- [ ] Implement token-first group resolution and delegated Graph fallback using `/v1.0/me/checkMemberGroups`; never call Graph when claims are complete.
- [ ] Ensure fallback 401/403/429/network errors produce a failed closed result with a non-sensitive reason code.
- [ ] Run identity/group tests; expected all pass.
- [ ] Commit as `feat: resolve trusted user and group identity`.

### Task 3: Implement location evaluation and trusted proxy boundaries

**Files:**
- Create: `src/SpeAuthorizationDemo/Location/LocationEvidence.cs`
- Create: `src/SpeAuthorizationDemo/Location/IClientLocationEvaluator.cs`
- Create: `src/SpeAuthorizationDemo/Location/ClientLocationEvaluator.cs`
- Create: `src/SpeAuthorizationDemo/Location/IGeoCountryResolver.cs`
- Create: `src/SpeAuthorizationDemo/Location/ConfiguredGeoCountryResolver.cs`
- Create: `src/SpeAuthorizationDemo/Location/CidrMatcher.cs`
- Test: `tests/SpeAuthorizationDemo.Tests/Location/CidrMatcherTests.cs`
- Test: `tests/SpeAuthorizationDemo.Tests/Location/ClientLocationEvaluatorTests.cs`

**Interfaces:**
- Produces `LocationEvidence(SourceIp, CountryCode, IsAllowedCidr, IsDevelopmentOverride, IsAllowed, ReasonCode)`.
- Consumes only `HttpContext.Connection.RemoteIpAddress` after ASP.NET forwarded-header middleware has validated known proxies/networks.

- [ ] Write tests for IPv4/IPv6 CIDR matches, CN Geo result, non-CN result, unknown/private/loopback denial, allowed CIDR precedence, permitted development override, production override rejection, and non-loopback override rejection.
- [ ] Run location tests and confirm they fail.
- [ ] Implement CIDR matching without external network calls.
- [ ] Implement a resolver contract with configuration-backed country mappings for deterministic local tests; document replacing it with an approved GeoIP provider for production.
- [ ] Implement the three-gate development override and fail-closed evaluation.
- [ ] Configure `ForwardedHeadersOptions` only from explicit KnownProxies/KnownNetworks settings and set a forward limit.
- [ ] Run location tests; expected all pass.
- [ ] Commit as `feat: enforce trusted client location rules`.

### Task 4: Implement the business authorization decision engine

**Files:**
- Create: `src/SpeAuthorizationDemo/Authorization/BusinessOperation.cs`
- Create: `src/SpeAuthorizationDemo/Authorization/BusinessRole.cs`
- Create: `src/SpeAuthorizationDemo/Authorization/AuthorizationDecision.cs`
- Create: `src/SpeAuthorizationDemo/Authorization/IBusinessAuthorizationService.cs`
- Create: `src/SpeAuthorizationDemo/Authorization/BusinessAuthorizationService.cs`
- Test: `tests/SpeAuthorizationDemo.Tests/Authorization/BusinessAuthorizationServiceTests.cs`

**Interfaces:**
- Produces `Task<AuthorizationDecision> AuthorizeAsync(ClaimsPrincipal user, HttpContext httpContext, BusinessOperation operation, CancellationToken cancellationToken)`.
- Decision contains only normalized evidence and reason codes, never tokens or secrets.

- [ ] Write table-driven tests for tenant mismatch, identity failure, group failure, location failure, no role, Reader/Writer/DemoAdmin matrices, and app-only comparison admin restriction.
- [ ] Run authorization tests and confirm they fail.
- [ ] Implement evaluation in fixed order: identity, tenant, groups, location, role, operation.
- [ ] Implement highest-role selection when a user belongs to more than one configured role group.
- [ ] Add structured logging fields for object ID, tenant, source IP, country, operation, role, container ID, decision and reason; do not log claims wholesale.
- [ ] Run authorization tests; expected all pass.
- [ ] Commit as `feat: add fail-closed business authorization`.

### Task 5: Implement delegated and app-only SPE Graph clients

**Files:**
- Create: `src/SpeAuthorizationDemo/Graph/ISpeGraphClient.cs`
- Create: `src/SpeAuthorizationDemo/Graph/SpeGraphClient.cs`
- Create: `src/SpeAuthorizationDemo/Graph/IGraphAccessTokenProvider.cs`
- Create: `src/SpeAuthorizationDemo/Graph/DelegatedGraphAccessTokenProvider.cs`
- Create: `src/SpeAuthorizationDemo/Graph/AppOnlyGraphAccessTokenProvider.cs`
- Create: `src/SpeAuthorizationDemo/Models/SpeDriveItem.cs`
- Create: `src/SpeAuthorizationDemo/Models/SpeDownload.cs`
- Create: `src/SpeAuthorizationDemo/Graph/SpeGraphException.cs`
- Create: `src/SpeAuthorizationDemo/Graph/FileNamePolicy.cs`
- Test: `tests/SpeAuthorizationDemo.Tests/Graph/SpeGraphClientTests.cs`
- Test: `tests/SpeAuthorizationDemo.Tests/Graph/FileNamePolicyTests.cs`

**Interfaces:**
- Produces `ListRootAsync`, `DownloadAsync(itemId)`, and `UploadSmallFileAsync(fileName, stream, length)`.
- Token providers return access tokens only to the server-side Graph client and never to page models.

- [ ] Write fake-HTTP tests proving the exact China Graph URLs use configured ContainerId and cannot be overridden by input.
- [ ] Write tests for bearer headers, JSON parsing, download streaming, URL-safe item IDs, file name/path rejection, 4 MB cap, 401/403/claims challenge mapping, read retry on 429/5xx, and no upload retry.
- [ ] Run Graph tests and confirm they fail.
- [ ] Implement delegated acquisition with Microsoft.Identity.Web using `FileStorageContainer.Selected`.
- [ ] Implement app-only acquisition with confidential-client MSAL and China authority, reading the secret from configuration.
- [ ] Implement typed HttpClient calls to `/v1.0/drives/{configuredContainerId}/root/children`, `/items/{id}/content`, and `/root:/{escapedName}:/content`.
- [ ] Add bounded exponential retry only for list/download and preserve Graph request IDs in sanitized exceptions.
- [ ] Run Graph tests; expected all pass.
- [ ] Commit as `feat: call SPE with delegated and app-only tokens`.

### Task 6: Build Razor Pages and authorization filters

**Files:**
- Modify: `src/SpeAuthorizationDemo/Program.cs`
- Create/modify: `src/SpeAuthorizationDemo/Pages/Index.cshtml(.cs)`
- Create: `src/SpeAuthorizationDemo/Pages/Files/Index.cshtml(.cs)`
- Create: `src/SpeAuthorizationDemo/Pages/Files/Download.cshtml.cs`
- Create: `src/SpeAuthorizationDemo/Pages/Files/Upload.cshtml(.cs)`
- Create: `src/SpeAuthorizationDemo/Pages/AppOnly/Index.cshtml(.cs)`
- Create: `src/SpeAuthorizationDemo/Pages/AccessDenied.cshtml(.cs)`
- Create: `src/SpeAuthorizationDemo/Pages/Shared/_AuthorizationSummary.cshtml`
- Modify: `src/SpeAuthorizationDemo/Pages/Shared/_Layout.cshtml`
- Modify: `src/SpeAuthorizationDemo/wwwroot/css/site.css`
- Test: `tests/SpeAuthorizationDemo.Tests/Pages/PageAuthorizationTests.cs`

**Interfaces:**
- Pages consume `IBusinessAuthorizationService` and the appropriate delegated/app-only `ISpeGraphClient` only after an allowed decision.

- [ ] Write page/service tests proving denied decisions never call Graph, Reader upload is denied, non-admin app-only is denied, and server configuration supplies ContainerId.
- [ ] Run page tests and confirm they fail.
- [ ] Register China-cloud OIDC, token acquisition, options validation, forwarded headers, HttpClients and domain services.
- [ ] Implement identity summary, local Development CN/US selector, delegated list/download/upload, and clearly labeled app-only comparison.
- [ ] Add antiforgery to uploads, content disposition safety for downloads, upload length checks before Graph calls, and non-sensitive error pages.
- [ ] Use a clean responsive UI and visibly label simulated location and app-only mode.
- [ ] Run page tests and the full test suite; expected all pass.
- [ ] Commit as `feat: add SPE authorization test UI`.

### Task 7: Add read-only discovery and explicit-apply identity scripts

**Files:**
- Create: `scripts/Discover-SpeEnvironment.ps1`
- Create: `scripts/Prepare-SpeTestIdentities.ps1`
- Create: `scripts/Test-ScriptSafety.ps1`

**Interfaces:**
- Discovery emits a JSON object containing non-secret TenantId, ContainerId, ContainerUrl, ContainerTypeId and app configuration findings.
- Preparation emits non-secret Object IDs; without `-Apply`, it produces a proposed change plan only.

- [ ] Add script safety checks that parse all scripts, assert `-Apply` guards mutation paths, and scan output statements for password/secret/token variables.
- [ ] Run safety checks before scripts exist and confirm failure.
- [ ] Implement China Graph connection with a custom China-registered App ID and process-scoped login.
- [ ] Implement SPO discovery by owning App ID and exact display name; fail on zero or multiple matches and dynamically inspect output properties.
- [ ] Inspect App Registration delegated/application permissions and localhost redirect URI without changing them.
- [ ] Implement idempotent group/user planning and explicit-apply creation; prompt securely for initial passwords only during apply and never echo them.
- [ ] Run PowerShell parser and safety checks; expected zero parse/safety failures.
- [ ] Commit as `feat: add SPE test environment scripts`.

### Task 8: Write the operational runbook

**Files:**
- Create: `SharePoint Embedded aka SPE/SPEBusinessAuthorizationDemo/README.md`

**Interfaces:**
- Documents exact inputs produced by scripts and exact User Secrets/environment variable keys consumed by the web app.

- [ ] Document prerequisites and why business authorization is additive rather than a native SPE/CA boundary.
- [ ] Document App Registration redirect URIs, China endpoints, delegated/application permissions, admin consent, optional `GroupMember.Read.All`, and group-claim fallback behavior.
- [ ] Document discovery, identity preparation, Container Type Registration least privilege, and Container user permission setup.
- [ ] Document User Secrets commands, local HTTPS launch, CN/US simulation matrix, expected Reader/Writer/Outside behavior, and app-only comparison.
- [ ] Document Azure China App Service creation, environment settings, trusted proxy handling, production redirect URI, deployment, and real mainland/overseas tests.
- [ ] Document sign-in log/Graph request ID troubleshooting, secret rotation, object cleanup and rollback.
- [ ] Scan README for placeholders and accidental secret-like strings; expected none.
- [ ] Commit as `docs: add SPE business authorization runbook`.

### Task 9: Final verification and review

**Files:**
- Review all files under `SharePoint Embedded aka SPE/SPEBusinessAuthorizationDemo`
- Review `.gitignore`

- [ ] Run `dotnet restore SPEBusinessAuthorizationDemo.sln`; expected exit 0.
- [ ] Run `dotnet build SPEBusinessAuthorizationDemo.sln --no-restore -warnaserror`; expected 0 warnings and 0 errors.
- [ ] Run `dotnet test SPEBusinessAuthorizationDemo.sln --no-build`; expected all tests pass.
- [ ] Run `pwsh -NoProfile -File scripts/Test-ScriptSafety.ps1`; expected zero parser/safety failures.
- [ ] Run repository secret scans for client-secret values, JWT-shaped strings, passwords, tenant IDs and non-example GUIDs; inspect every match.
- [ ] Run `git diff --check`; expected no whitespace errors.
- [ ] Review the acceptance matrix requirement-by-requirement and explicitly report that tenant-connected tests remain pending until the user supplies local secrets and executes the runbook.
- [ ] Request code review and address concrete findings.
- [ ] Commit final verification-only fixes, if any, as `fix: address SPE demo verification findings`.
