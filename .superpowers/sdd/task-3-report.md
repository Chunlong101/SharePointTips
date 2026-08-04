# Task 3 Report

## Status

Implemented and committed Task 3: one-shot loopback OAuth callback handling and interactive authentication orchestration.

## RED Evidence

Command (run from `Python Graph Delegated Auth in 21V Gallatin/`):

`.\.venv\Scripts\python.exe -m pytest tests/test_oauth_pkce.py -k "callback or authenticate" -v`

Result: **exit code 1**, collection failed exactly because the new interface did not exist:

- `ImportError: cannot import name 'CallbackResult' from 'src.oauth_pkce'`
- `collected 0 items / 1 error`
- `1 error in 0.56s`

No production implementation had been added before this RED run.

## GREEN Evidence

Focused command:

`.\.venv\Scripts\python.exe -m pytest tests/test_oauth_pkce.py -k "callback or authenticate" -v`

Result: **exit code 0** — `11 passed, 8 deselected in 0.33s`.

Full OAuth command:

`.\.venv\Scripts\python.exe -m pytest tests/test_oauth_pkce.py -v`

Result: **exit code 0** — `19 passed in 0.37s`.

Additional checks:

- VS Code diagnostics: no errors in either changed file.
- `git diff --check` on both task files: exit code 0 with no output.
- Browser and HTTP server behavior were replaced with fakes in orchestration/server tests; automated tests opened no browser and listened on no real socket.

## Files

- `Python Graph Delegated Auth in 21V Gallatin/src/oauth_pkce.py`
- `Python Graph Delegated Auth in 21V Gallatin/tests/test_oauth_pkce.py`

## Commit

- `8030ad3731ee5545a39d6e4a46297f3aefae0386`
- `feat: add secure localhost OAuth callback`
- The commit contains only the two planned Task 3 files.

## Self-Review

- `CallbackResult` contains only the four planned callback fields.
- The loopback server derives the host, port, and exact callback path from the configured redirect URI, handles one request, applies the requested timeout, suppresses request logging, and closes from `__exit__`.
- Callback parsing ignores unrecognized query parameters; both success and error HTML are constant and exclude code, state, token, verifier, and OAuth details.
- Authentication constructs the callback before browser launch, uses the Gallatin authorization URL, handles browser failure and OAuth denial safely, validates required callback fields, compares state with `secrets.compare_digest`, exchanges the original code/verifier, and returns only the access token.
- Focused handler tests cover success, OAuth denial, and wrong paths. Orchestration tests cover ordering, browser failure, missing/mismatched callback data, safe OAuth errors, exchange inputs, and token-only return behavior.

## Concerns

None.

---

# Important Findings Fix Report

## Status

Fixed both Important Task 3 review findings using strict test-first development.

## RED Evidence

Command (run from `Python Graph Delegated Auth in 21V Gallatin/`):

`.\.venv\Scripts\python.exe -m pytest tests/test_oauth_pkce.py -k "ignores_wrong_path or raises_safe_timeout or rejects_oauth_error_until_state_is_validated" -v`

Result: **exit code 1** — `4 failed, 17 deselected in 1.78s`.

- The valid callback after a wrong-path probe timed out because `wait()` had already returned after one request.
- The deadline regression showed that `monotonic()` was never called.
- Missing-state and forged-state OAuth errors both exposed `access_denied` instead of returning state-validation errors.

No production changes were made before this RED run.

## Fix

- `authenticate()` now rejects a missing state and performs `secrets.compare_digest()` before inspecting OAuth error or success fields. Missing/forged-state error callbacks return only state errors and do not expose the OAuth error, description, or authorization code.
- `LoopbackCallbackServer.wait()` now computes one monotonic deadline, repeatedly blocks in `handle_request()` with only the remaining time, ignores wrong-path requests that produce no `CallbackResult`, and raises the existing safe timeout error when the overall deadline expires.
- Added a real loopback server regression that sends a wrong-path request followed by a valid callback without sleeps, plus deterministic patched-clock timeout coverage.

## GREEN Evidence

Focused command:

`.\.venv\Scripts\python.exe -m pytest tests/test_oauth_pkce.py -k "ignores_wrong_path or raises_safe_timeout or rejects_oauth_error_until_state_is_validated or rejects_invalid_callback" -v`

Result: **exit code 0** — `7 passed, 14 deselected in 0.36s`.

Full OAuth command:

`.\.venv\Scripts\python.exe -m pytest tests/test_oauth_pkce.py -v`

Result: **exit code 0** — `21 passed in 0.35s`.

Additional checks:

- VS Code diagnostics: no errors in either changed Python file.
- `git diff --check`: exit code 0 with no output.

## Files

- `Python Graph Delegated Auth in 21V Gallatin/src/oauth_pkce.py`
- `Python Graph Delegated Auth in 21V Gallatin/tests/test_oauth_pkce.py`
- `.superpowers/sdd/task-3-report.md`

## Commit

- `fix: harden OAuth callback validation`

## Concerns

None.
