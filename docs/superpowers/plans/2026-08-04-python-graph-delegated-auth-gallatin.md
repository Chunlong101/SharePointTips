# Python Gallatin Delegated Graph Demo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Python CLI Demo that implements OAuth 2.0 Authorization Code Flow with PKCE directly and uses 21V Gallatin Microsoft Graph to list, upload, and download files in a SharePoint Online site's default document library.

**Architecture:** A thin `argparse` entry point coordinates independent configuration, OAuth/loopback callback, and Graph HTTP components. Authentication state remains in memory for one command invocation; all network, browser, clock, and sleep dependencies are injectable so unit tests never contact a real tenant.

**Tech Stack:** Python 3.10+, Python standard library, `requests`, `python-dotenv`, `pytest`, `responses`

## Global Constraints

- Create the project under `Python Graph Delegated Auth in 21V Gallatin/`.
- Use `https://login.partner.microsoftonline.cn/{tenant_id}/oauth2/v2.0/authorize` and `/token`; never use the global login host.
- Use `https://microsoftgraph.chinacloudapi.cn/v1.0`; never use `graph.microsoft.com`.
- Implement Authorization Code Flow with S256 PKCE directly; do not use MSAL, Graph SDK, Client Secret, Device Code Flow, or Client Credentials Flow.
- Request exactly `openid profile User.Read Sites.Read.All Files.ReadWrite.All`; do not request `offline_access`.
- Never persist or print access tokens, authorization codes, PKCE verifiers, or complete token responses.
- Support only a configured `.sharepoint.cn` site and its default document library.
- Every CLI invocation authenticates interactively and discards the token on exit.
- Keep TLS verification enabled and set connect/read timeouts on every HTTP request.
- Use tests first for every behavior; no automated test may require a real tenant, browser, or network connection.

---

## File Map

- `Python Graph Delegated Auth in 21V Gallatin/requirements.txt`: pinned-compatible runtime and test dependencies.
- `Python Graph Delegated Auth in 21V Gallatin/.gitignore`: excludes secrets, environments, caches, coverage, and local downloads.
- `Python Graph Delegated Auth in 21V Gallatin/.env.example`: non-secret Gallatin configuration template.
- `Python Graph Delegated Auth in 21V Gallatin/main.py`: CLI parser, orchestration, output, and exit-code mapping only.
- `Python Graph Delegated Auth in 21V Gallatin/src/__init__.py`: package marker.
- `Python Graph Delegated Auth in 21V Gallatin/src/errors.py`: typed domain errors and stable exit codes.
- `Python Graph Delegated Auth in 21V Gallatin/src/config.py`: environment loading, URI validation, and site URL decomposition.
- `Python Graph Delegated Auth in 21V Gallatin/src/oauth_pkce.py`: PKCE generation, authorization URL, one-shot loopback callback, and token exchange.
- `Python Graph Delegated Auth in 21V Gallatin/src/graph_client.py`: Gallatin Graph transport, retry, site/drive resolution, listing, upload, and download.
- `Python Graph Delegated Auth in 21V Gallatin/tests/conftest.py`: reusable settings and fake response fixtures.
- `Python Graph Delegated Auth in 21V Gallatin/tests/test_config.py`: configuration tests.
- `Python Graph Delegated Auth in 21V Gallatin/tests/test_oauth_pkce.py`: PKCE, callback, URL, and token exchange tests.
- `Python Graph Delegated Auth in 21V Gallatin/tests/test_graph_client.py`: Graph URL, retry, list, upload, and download tests.
- `Python Graph Delegated Auth in 21V Gallatin/tests/test_cli.py`: CLI dispatch, output, redaction, and exit-code tests.
- `Python Graph Delegated Auth in 21V Gallatin/README.md`: Chinese registration, setup, commands, acceptance, and troubleshooting guide.

---

### Task 1: Project Foundation, Errors, and Configuration

**Files:**
- Create: `Python Graph Delegated Auth in 21V Gallatin/requirements.txt`
- Create: `Python Graph Delegated Auth in 21V Gallatin/src/__init__.py`
- Create: `Python Graph Delegated Auth in 21V Gallatin/src/errors.py`
- Create: `Python Graph Delegated Auth in 21V Gallatin/src/config.py`
- Create: `Python Graph Delegated Auth in 21V Gallatin/tests/test_config.py`

**Interfaces:**
- Produces: `ExitCode(IntEnum)`, `DemoError`, `ConfigError`, `AuthError`, `GraphError`, `LocalFileError`.
- Produces: immutable `Settings(tenant_id, client_id, sharepoint_site_url, redirect_uri)` with `site_hostname`, `site_path`, `authorize_endpoint`, and `token_endpoint` properties.
- Produces: `load_settings(env_file: str | Path = ".env", environ: Mapping[str, str] | None = None) -> Settings`.

- [ ] **Step 1: Add dependencies and failing configuration tests**

Create `requirements.txt`:

```text
requests>=2.32,<3
python-dotenv>=1.0,<2
pytest>=8,<9
responses>=0.25,<1
```

Create `src/__init__.py` as an empty file. Create tests asserting exact Gallatin endpoints and validation:

```python
# tests/test_config.py
from pathlib import Path
import pytest
from src.config import load_settings
from src.errors import ConfigError

VALID = {
    "TENANT_ID": "00000000-0000-0000-0000-000000000001",
    "CLIENT_ID": "00000000-0000-0000-0000-000000000002",
    "SHAREPOINT_SITE_URL": "https://contoso.sharepoint.cn/sites/演示 Site",
    "REDIRECT_URI": "http://localhost:8400/callback",
}

def test_loads_gallatin_settings_without_reading_process_environment(tmp_path: Path):
    settings = load_settings(tmp_path / "missing.env", VALID)
    assert settings.site_hostname == "contoso.sharepoint.cn"
    assert settings.site_path == "/sites/演示 Site"
    assert settings.authorize_endpoint.endswith("/oauth2/v2.0/authorize")
    assert settings.authorize_endpoint.startswith("https://login.partner.microsoftonline.cn/")
    assert settings.token_endpoint.endswith("/oauth2/v2.0/token")

@pytest.mark.parametrize("key", VALID)
def test_rejects_missing_required_value(tmp_path: Path, key: str):
    values = VALID | {key: ""}
    with pytest.raises(ConfigError, match=key):
        load_settings(tmp_path / "missing.env", values)

@pytest.mark.parametrize("site_url", [
    "http://contoso.sharepoint.cn/sites/Demo",
    "https://contoso.sharepoint.com/sites/Demo",
    "https://evil.example/sites/Demo",
])
def test_rejects_non_gallatin_site(tmp_path: Path, site_url: str):
    with pytest.raises(ConfigError, match="sharepoint.cn"):
        load_settings(tmp_path / "missing.env", VALID | {"SHAREPOINT_SITE_URL": site_url})

@pytest.mark.parametrize("redirect", [
    "https://localhost:8400/callback",
    "http://example.com:8400/callback",
    "http://localhost/callback",
])
def test_rejects_invalid_loopback_redirect(tmp_path: Path, redirect: str):
    with pytest.raises(ConfigError, match="REDIRECT_URI"):
        load_settings(tmp_path / "missing.env", VALID | {"REDIRECT_URI": redirect})
```

- [ ] **Step 2: Install dependencies and verify tests fail**

Run from the project directory:

```text
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m pytest tests/test_config.py -v
```

Expected: collection fails because `src.config` and `src.errors` do not exist.

- [ ] **Step 3: Implement domain errors and configuration**

Implement `src/errors.py` with `ExitCode` values `OK=0`, `UNEXPECTED=1`, `USAGE=2`, `CONFIG=10`, `AUTH=20`, `GRAPH=30`, `LOCAL_FILE=40`. `DemoError` accepts a safe message and each subclass exposes the matching exit code.

Implement `src/config.py` with:

```python
@dataclass(frozen=True)
class Settings:
    tenant_id: str
    client_id: str
    sharepoint_site_url: str
    redirect_uri: str

    @property
    def authorize_endpoint(self) -> str:
        return f"https://login.partner.microsoftonline.cn/{self.tenant_id}/oauth2/v2.0/authorize"

    @property
    def token_endpoint(self) -> str:
        return f"https://login.partner.microsoftonline.cn/{self.tenant_id}/oauth2/v2.0/token"
```

Use `dotenv_values(env_file)` followed by process/environment overrides. Validate both IDs with `uuid.UUID`, require a query/fragment-free HTTPS site URL whose lowercase hostname ends with `.sharepoint.cn`, and require `REDIRECT_URI` to be HTTP, hostname `localhost` or `127.0.0.1`, an explicit port, no query/fragment, and a non-root callback path. Normalize the site URL by removing one trailing slash while preserving decoded Unicode path text.

- [ ] **Step 4: Run configuration tests**

Run:

```text
.\.venv\Scripts\python.exe -m pytest tests/test_config.py -v
```

Expected: all tests pass.

- [ ] **Step 5: Commit foundation**

```text
git add "Python Graph Delegated Auth in 21V Gallatin/requirements.txt" "Python Graph Delegated Auth in 21V Gallatin/src" "Python Graph Delegated Auth in 21V Gallatin/tests/test_config.py"
git commit -m "feat: add Gallatin demo configuration"
```

---

### Task 2: PKCE, Authorization URL, and Token Exchange

**Files:**
- Create: `Python Graph Delegated Auth in 21V Gallatin/src/oauth_pkce.py`
- Create: `Python Graph Delegated Auth in 21V Gallatin/tests/test_oauth_pkce.py`

**Interfaces:**
- Consumes: `Settings`, `AuthError`.
- Produces: `SCOPES: tuple[str, ...]` containing exactly `openid`, `profile`, `User.Read`, `Sites.Read.All`, `Files.ReadWrite.All`.
- Produces: `PkcePair(verifier: str, challenge: str)`, `generate_pkce() -> PkcePair`, `generate_state() -> str`.
- Produces: `build_authorization_url(settings: Settings, state: str, challenge: str) -> str`.
- Produces: `exchange_code(settings: Settings, code: str, verifier: str, session: requests.Session) -> str` returning only the access token.

- [ ] **Step 1: Write failing PKCE and OAuth request tests**

Add tests that patch `secrets.token_urlsafe`, independently calculate `BASE64URL(SHA256(verifier))`, parse the authorization URL with `urllib.parse.parse_qs`, and assert:

```python
assert query["client_id"] == [settings.client_id]
assert query["response_type"] == ["code"]
assert query["response_mode"] == ["query"]
assert query["redirect_uri"] == [settings.redirect_uri]
assert query["scope"] == ["openid profile User.Read Sites.Read.All Files.ReadWrite.All"]
assert query["code_challenge_method"] == ["S256"]
assert "offline_access" not in query["scope"][0]
```

Use `responses` to verify token exchange sends `grant_type=authorization_code`, client ID, code, redirect URI, and verifier to `settings.token_endpoint`, never sends `client_secret`, returns only `access_token`, and raises `AuthError` for OAuth error JSON, non-JSON, or a success response without `access_token`. Include a regression test whose fake response contains `super-secret-token` and assert that string is absent from `str(error)`.

- [ ] **Step 2: Run tests and verify failure**

Run:

```text
.\.venv\Scripts\python.exe -m pytest tests/test_oauth_pkce.py -v
```

Expected: collection fails because `src.oauth_pkce` does not exist.

- [ ] **Step 3: Implement PKCE and token exchange**

Implement:

```python
SCOPES = ("openid", "profile", "User.Read", "Sites.Read.All", "Files.ReadWrite.All")
HTTP_TIMEOUT = (10, 30)

@dataclass(frozen=True)
class PkcePair:
    verifier: str
    challenge: str

def generate_pkce() -> PkcePair:
    verifier = secrets.token_urlsafe(64)
    digest = hashlib.sha256(verifier.encode("ascii")).digest()
    challenge = base64.urlsafe_b64encode(digest).rstrip(b"=").decode("ascii")
    return PkcePair(verifier, challenge)
```

`build_authorization_url()` must use `urllib.parse.urlencode`. `exchange_code()` must submit form data with `requests.Session.post(..., timeout=HTTP_TIMEOUT)`, translate transport/JSON/OAuth failures to sanitized `AuthError`, and return only the token string. Do not include response bodies in exception messages.

- [ ] **Step 4: Run OAuth tests**

Run:

```text
.\.venv\Scripts\python.exe -m pytest tests/test_oauth_pkce.py -v
```

Expected: PKCE, URL, and token exchange tests pass.

- [ ] **Step 5: Commit OAuth core**

```text
git add "Python Graph Delegated Auth in 21V Gallatin/src/oauth_pkce.py" "Python Graph Delegated Auth in 21V Gallatin/tests/test_oauth_pkce.py"
git commit -m "feat: implement Gallatin OAuth PKCE exchange"
```

---

### Task 3: One-Shot Localhost Callback and Interactive Authentication

**Files:**
- Modify: `Python Graph Delegated Auth in 21V Gallatin/src/oauth_pkce.py`
- Modify: `Python Graph Delegated Auth in 21V Gallatin/tests/test_oauth_pkce.py`

**Interfaces:**
- Produces: `CallbackResult(code: str | None, state: str | None, error: str | None, error_description: str | None)`.
- Produces: `LoopbackCallbackServer(redirect_uri: str)` context manager with `wait(timeout_seconds: float) -> CallbackResult`.
- Produces: `authenticate(settings: Settings, session: requests.Session, browser_open: Callable[[str], bool] = webbrowser.open, callback_factory: Callable[[str], ContextManager] = LoopbackCallbackServer) -> str`.

- [ ] **Step 1: Add failing callback and orchestration tests**

Use a fake callback context manager rather than opening a socket for orchestration tests. Assert `authenticate()`:

- creates the callback server before opening the browser;
- opens the Gallatin authorization URL;
- rejects browser-open failure;
- rejects missing/mismatched `state` before token exchange;
- surfaces `error=access_denied` without exposing the authorization code;
- passes the returned code and original verifier to `exchange_code()`;
- returns only the access token.

Add focused handler tests by passing paths such as:

```text
/callback?code=abc&state=expected
/callback?error=access_denied&error_description=Denied&state=expected
/wrong?code=abc&state=expected
```

Assert the success HTML contains no code, state, token, or verifier.

- [ ] **Step 2: Run callback tests and verify failure**

Run:

```text
.\.venv\Scripts\python.exe -m pytest tests/test_oauth_pkce.py -k "callback or authenticate" -v
```

Expected: fails because callback and orchestration symbols are undefined.

- [ ] **Step 3: Implement one-shot callback and authentication**

Parse the configured redirect URI into host, port, and exact path. Build a private `BaseHTTPRequestHandler` subclass that accepts one expected GET, parses only `code`, `state`, `error`, and `error_description`, stores `CallbackResult`, returns minimal UTF-8 HTML, and suppresses default request logging. `LoopbackCallbackServer` must use `HTTPServer`, set a socket timeout, handle one request, raise `AuthError("等待登录回调超时")` when no result arrives, and always close in `__exit__`.

`authenticate()` must:

```python
pkce = generate_pkce()
state = generate_state()
with callback_factory(settings.redirect_uri) as callback:
    url = build_authorization_url(settings, state, pkce.challenge)
    if not browser_open(url):
        raise AuthError("无法打开系统浏览器")
    result = callback.wait(timeout_seconds=180)
```

Then reject OAuth errors, missing code/state, and non-constant-time state mismatch using `secrets.compare_digest`; finally call `exchange_code()`.

- [ ] **Step 4: Run all OAuth tests**

Run:

```text
.\.venv\Scripts\python.exe -m pytest tests/test_oauth_pkce.py -v
```

Expected: all tests pass without opening a browser or listening on a real port.

- [ ] **Step 5: Commit interactive authentication**

```text
git add "Python Graph Delegated Auth in 21V Gallatin/src/oauth_pkce.py" "Python Graph Delegated Auth in 21V Gallatin/tests/test_oauth_pkce.py"
git commit -m "feat: add secure localhost OAuth callback"
```

---

### Task 4: Graph Transport, Site Resolution, and Listing

**Files:**
- Create: `Python Graph Delegated Auth in 21V Gallatin/src/graph_client.py`
- Create: `Python Graph Delegated Auth in 21V Gallatin/tests/conftest.py`
- Create: `Python Graph Delegated Auth in 21V Gallatin/tests/test_graph_client.py`

**Interfaces:**
- Consumes: `Settings`, `GraphError`.
- Produces: `encode_remote_path(path: str, allow_empty: bool = False) -> str`.
- Produces: `GraphClient(access_token: str, session: requests.Session | None = None, sleep: Callable[[float], None] = time.sleep)`.
- Produces: `get_current_user() -> dict[str, Any]`, `resolve_default_drive(settings: Settings) -> tuple[str, str]`, and `list_children(drive_id: str, folder: str = "") -> list[dict[str, Any]]`.

- [ ] **Step 1: Write failing path, transport, site, retry, and pagination tests**

Test exact URL behavior:

```python
assert encode_remote_path("中文 Folder/a#b.txt") == "%E4%B8%AD%E6%96%87%20Folder/a%23b.txt"
```

Reject `/absolute`, `a//b`, `.`, `..`, `a/../b`, and empty file paths. Mock Graph to assert:

- Authorization header is `Bearer token` but failures never include `token`;
- `/me?$select=id,displayName,userPrincipalName` uses the China Graph host;
- site lookup is `/sites/contoso.sharepoint.cn:/sites/Demo` with a correctly encoded path;
- default drive lookup is `/sites/{site-id}/drive`;
- root and folder listing URLs are distinct;
- all `@odata.nextLink` pages are followed only when their host remains `microsoftgraph.chinacloudapi.cn`;
- `429` honors numeric `Retry-After` and succeeds on retry;
- retry count is bounded for `429` and `500`;
- `401`, `403`, `404`, and malformed responses raise sanitized `GraphError` containing status, Graph code, and request ID.

- [ ] **Step 2: Run Graph tests and verify failure**

Run:

```text
.\.venv\Scripts\python.exe -m pytest tests/test_graph_client.py -v
```

Expected: collection fails because `src.graph_client` does not exist.

- [ ] **Step 3: Implement Graph transport and read operations**

Define constants:

```python
GRAPH_BASE_URL = "https://microsoftgraph.chinacloudapi.cn/v1.0"
GRAPH_HOST = "microsoftgraph.chinacloudapi.cn"
HTTP_TIMEOUT = (10, 60)
MAX_RETRIES = 3
MAX_RETRY_AFTER = 30
```

Use `quote(segment, safe="")` per validated segment. `GraphClient._request()` must create a fresh `client-request-id`, send `Accept: application/json`, enforce timeout/TLS defaults, parse Graph errors without response-body leakage, and retry transport errors, `429`, `500`, `502`, `503`, and `504` only up to `MAX_RETRIES`. Clamp `Retry-After` to `MAX_RETRY_AFTER`.

`resolve_default_drive()` returns `(site_id, drive_id)`. `list_children()` follows pagination and verifies every absolute next-link scheme is HTTPS and host equals `GRAPH_HOST` before requesting it.

- [ ] **Step 4: Run Graph read tests**

Run:

```text
.\.venv\Scripts\python.exe -m pytest tests/test_graph_client.py -v
```

Expected: path, current-user, site, drive, pagination, retry, and error tests pass.

- [ ] **Step 5: Commit Graph read client**

```text
git add "Python Graph Delegated Auth in 21V Gallatin/src/graph_client.py" "Python Graph Delegated Auth in 21V Gallatin/tests/conftest.py" "Python Graph Delegated Auth in 21V Gallatin/tests/test_graph_client.py"
git commit -m "feat: add Gallatin Graph read operations"
```

---

### Task 5: Safe Upload and Atomic Download

**Files:**
- Modify: `Python Graph Delegated Auth in 21V Gallatin/src/graph_client.py`
- Modify: `Python Graph Delegated Auth in 21V Gallatin/tests/test_graph_client.py`

**Interfaces:**
- Consumes: `encode_remote_path`, `GraphClient._request`, `LocalFileError`.
- Produces: `remote_item_exists(drive_id: str, remote_path: str) -> bool`.
- Produces: `upload_file(drive_id: str, source: Path, destination: str, overwrite: bool = False) -> dict[str, Any]`.
- Produces: `download_file(drive_id: str, source: str, destination: Path, overwrite: bool = False) -> Path`.

- [ ] **Step 1: Write failing upload and download tests**

Test that upload rejects a missing/non-file source, a source larger than `250 * 1024 * 1024`, invalid destination, and an existing target without `overwrite`. Assert the PUT uses:

```text
/drives/{drive-id}/root:/{encoded-path}:/content
```

with `Content-Type: application/octet-stream` and a file stream rather than preloading bytes.

Test that download rejects existing local targets without `overwrite`, creates parents, streams chunks to a same-directory temporary file, calls `os.replace()` only after success, follows the Graph 302 download redirect, and removes the temporary file after an interrupted response. Verify the final file bytes exactly match the mocked content.

- [ ] **Step 2: Run file-operation tests and verify failure**

Run:

```text
.\.venv\Scripts\python.exe -m pytest tests/test_graph_client.py -k "upload or download or exists" -v
```

Expected: fails because file-operation methods are undefined.

- [ ] **Step 3: Implement upload and download**

`remote_item_exists()` performs a metadata GET and returns false only for a parsed Graph `404`; other errors propagate. `upload_file()` performs preflight validation and existence checking, opens the source in `rb`, and sends the PUT once. Do not automatically create remote directories and do not retry a PUT after request bytes may have been sent.

`download_file()` validates before network access, creates the parent, uses `tempfile.NamedTemporaryFile(delete=False, dir=destination.parent)`, writes non-empty `iter_content(64 * 1024)` chunks, flushes and closes, then calls `os.replace(temp_name, destination)`. A `finally` block deletes a surviving temp file. Wrap local I/O failures as `LocalFileError` without exposing authentication data.

- [ ] **Step 4: Run all Graph tests**

Run:

```text
.\.venv\Scripts\python.exe -m pytest tests/test_graph_client.py -v
```

Expected: all read, upload, download, retry, and cleanup tests pass.

- [ ] **Step 5: Commit file operations**

```text
git add "Python Graph Delegated Auth in 21V Gallatin/src/graph_client.py" "Python Graph Delegated Auth in 21V Gallatin/tests/test_graph_client.py"
git commit -m "feat: add safe Graph upload and download"
```

---

### Task 6: CLI Orchestration and Stable Exit Codes

**Files:**
- Create: `Python Graph Delegated Auth in 21V Gallatin/main.py`
- Create: `Python Graph Delegated Auth in 21V Gallatin/tests/test_cli.py`

**Interfaces:**
- Consumes: `load_settings`, `authenticate`, `GraphClient`, all domain errors.
- Produces: `build_parser() -> argparse.ArgumentParser`, `run(args: argparse.Namespace, dependencies: Dependencies | None = None) -> int`, and `main() -> int`.
- Produces CLI commands `login`, `list [--folder]`, `upload --source --destination [--overwrite]`, and `download --source --destination [--overwrite]`.

- [ ] **Step 1: Write failing CLI tests**

Use dependency fakes to assert:

- every valid command calls authentication exactly once;
- `login` prints display name and UPN, not token or ID;
- `list` prints tabular type/name/size/modified/web URL for all returned items;
- upload/download pass exact paths and overwrite flags and print concise success messages;
- `ConfigError`, `AuthError`, `GraphError`, and `LocalFileError` map to `10`, `20`, `30`, and `40` on stderr;
- unexpected exceptions return `1` with no traceback or secret;
- malformed arguments return argparse exit code `2`;
- output never contains a fake token value supplied by the authentication fake.

- [ ] **Step 2: Run CLI tests and verify failure**

Run:

```text
.\.venv\Scripts\python.exe -m pytest tests/test_cli.py -v
```

Expected: collection fails because `main.py` does not exist.

- [ ] **Step 3: Implement CLI**

Build required subparsers and typed `Path` arguments. `run()` loads settings, creates one `requests.Session`, calls `authenticate()`, creates `GraphClient`, and dispatches. Resolve the default drive only for `list`, `upload`, and `download`. Format folders as `DIR` and files as `FILE`; use `-` for missing optional values.

Use this exception boundary:

```python
try:
    return run(parser.parse_args())
except DemoError as error:
    print(f"错误: {error}", file=sys.stderr)
    return int(error.exit_code)
except Exception:
    print("错误: 发生未预期错误；请使用文档中的排错步骤。", file=sys.stderr)
    return int(ExitCode.UNEXPECTED)
```

The module ends with `raise SystemExit(main())`.

- [ ] **Step 4: Run CLI tests and CLI help smoke test**

Run:

```text
.\.venv\Scripts\python.exe -m pytest tests/test_cli.py -v
.\.venv\Scripts\python.exe main.py --help
```

Expected: tests pass; help shows all four subcommands and exits `0` without loading `.env` or opening a browser.

- [ ] **Step 5: Commit CLI**

```text
git add "Python Graph Delegated Auth in 21V Gallatin/main.py" "Python Graph Delegated Auth in 21V Gallatin/tests/test_cli.py"
git commit -m "feat: add Gallatin SharePoint file CLI"
```

---

### Task 7: Chinese Setup, Registration, Operation, and Troubleshooting Guide

**Files:**
- Create: `Python Graph Delegated Auth in 21V Gallatin/.env.example`
- Create: `Python Graph Delegated Auth in 21V Gallatin/.gitignore`
- Create: `Python Graph Delegated Auth in 21V Gallatin/README.md`

**Interfaces:**
- Consumes: exact CLI commands, scopes, endpoints, configuration names, exit codes, and limitations implemented in Tasks 1–6.
- Produces: a clean-clone runbook and manual Gallatin acceptance procedure.

- [ ] **Step 1: Add a failing documentation contract test**

Extend `tests/test_cli.py` with a parameterized test that reads README and asserts it contains all of these literal values:

```python
REQUIRED_DOC_TEXT = [
    "https://portal.azure.cn",
    "login.partner.microsoftonline.cn",
    "microsoftgraph.chinacloudapi.cn",
    "User.Read",
    "Sites.Read.All",
    "Files.ReadWrite.All",
    "http://localhost:8400/callback",
    "AADSTS700016",
    "AADSTS7000218",
    "python main.py login",
    "python main.py list",
    "python main.py upload",
    "python main.py download",
]
```

Also assert `.env.example` contains all four configuration keys and no value matching common secret names such as `CLIENT_SECRET`, `ACCESS_TOKEN`, or `PASSWORD`.

- [ ] **Step 2: Run documentation tests and verify failure**

Run:

```text
.\.venv\Scripts\python.exe -m pytest tests/test_cli.py -k documentation -v
```

Expected: fails because README and `.env.example` do not exist.

- [ ] **Step 3: Create configuration template and ignore rules**

Create `.env.example` exactly as approved in the design, with example GUIDs, `https://contoso.sharepoint.cn/sites/Demo`, and `http://localhost:8400/callback`.

Create `.gitignore` covering:

```text
.env
.venv/
__pycache__/
*.py[cod]
.pytest_cache/
.coverage
htmlcov/
downloads/
*.tmp
```

- [ ] **Step 4: Write the Chinese README**

Include these complete sections:

1. Demo goal, supported operations, and explicit exclusions.
2. Architecture and authentication sequence.
3. Gallatin versus Global endpoint table.
4. Prerequisites: Windows, Python 3.10+, Gallatin tenant/user, and access to the target site.
5. Exact portal steps: single-tenant registration; Mobile and desktop platform; localhost URI; public client flow enabled; three delegated permissions; consent; copy IDs; no secret.
6. Manifest verification showing `isFallbackPublicClient: true`, localhost in `publicClient.redirectUris`, and an empty Web redirect list.
7. Virtual environment, dependency installation, `.env` copy, and configuration commands.
8. Exact `login`, root/folder `list`, `upload`, overwrite, `download`, and overwrite examples.
9. Output field definitions, 250 MB upload limit, existing remote folder requirement, no token persistence, and one login per command.
10. Manual acceptance: login, list, upload, download, and PowerShell `Get-FileHash -Algorithm SHA256` comparison.
11. Exit-code table.
12. Troubleshooting for global/Gallatin endpoint mixing, `AADSTS700016`, `AADSTS7000218`, redirect mismatch, `403`, `404`, occupied port, hidden browser, Conditional Access, and `429`.
13. Security notes stating what is never logged or persisted.
14. Links to Microsoft national cloud, OAuth authorization code/PKCE, Graph site, drive, upload, and download documentation plus the repository's existing Gallatin reference article.

- [ ] **Step 5: Run documentation and full unit tests**

Run:

```text
.\.venv\Scripts\python.exe -m pytest -v
```

Expected: documentation contract and all prior tests pass.

- [ ] **Step 6: Commit documentation**

```text
git add "Python Graph Delegated Auth in 21V Gallatin/.env.example" "Python Graph Delegated Auth in 21V Gallatin/.gitignore" "Python Graph Delegated Auth in 21V Gallatin/README.md" "Python Graph Delegated Auth in 21V Gallatin/tests/test_cli.py"
git commit -m "docs: add Gallatin delegated auth runbook"
```

---

### Task 8: Final Verification and Security Review

**Files:**
- Modify only files required by failures discovered during this task.

**Interfaces:**
- Consumes: complete Demo and test suite.
- Produces: verified clean working tree and evidence that the deliverable satisfies the approved design.

- [ ] **Step 1: Run formatting-independent syntax checks**

Run:

```text
.\.venv\Scripts\python.exe -m compileall -q main.py src tests
```

Expected: exit code `0` and no output.

- [ ] **Step 2: Run the complete test suite**

Run:

```text
.\.venv\Scripts\python.exe -m pytest -v
```

Expected: all tests pass; no test opens a browser or accesses the network.

- [ ] **Step 3: Verify CLI help and missing-config behavior**

Run:

```text
.\.venv\Scripts\python.exe main.py --help
.\.venv\Scripts\python.exe main.py login
```

Expected: help exits `0`; with no local `.env`, login exits `10` and identifies missing configuration without opening a browser.

- [ ] **Step 4: Scan tracked content for secrets and global endpoints**

Run from the repository root:

```text
git grep -n -E "client_secret|access_token=|refresh_token|graph\.microsoft\.com|login\.microsoftonline\.com" -- "Python Graph Delegated Auth in 21V Gallatin"
```

Expected: no credential assignment and no global endpoint in executable/config files. README may mention global endpoint names only in clearly labeled comparison/troubleshooting text; inspect every match manually.

- [ ] **Step 5: Check repository diff and accidental artifacts**

Run:

```text
git status --short
git diff --check
git ls-files "Python Graph Delegated Auth in 21V Gallatin" | Select-String -Pattern "\.env$|\.venv|__pycache__|\.pytest_cache|downloads"
```

Expected: no whitespace errors and no secret, virtual environment, cache, or download artifact is tracked.

- [ ] **Step 6: Commit verification fixes if any**

If Steps 1–5 required code or documentation corrections, stage only those paths and commit:

```text
git commit -m "fix: address Gallatin demo verification findings"
```

If no correction was required, do not create an empty commit.

- [ ] **Step 7: Record real-tenant verification boundary**

Report that automated verification is complete. Do not claim the Gallatin end-to-end flow ran unless the user supplies local `.env` values and performs the interactive login. Point the user to the README manual acceptance section for application registration and the live login/list/upload/download test.
