import base64
import hashlib
from contextlib import AbstractContextManager
from io import BytesIO
from typing import Self
from unittest.mock import patch
from urllib.parse import parse_qs, urlsplit

import pytest
import requests
import responses
from responses import matchers

from src.config import Settings
from src.errors import AuthError
import src.oauth_pkce as oauth_pkce
from src.oauth_pkce import (
    CallbackResult,
    HTTP_TIMEOUT,
    LoopbackCallbackServer,
    PkcePair,
    SCOPES,
    authenticate,
    build_authorization_url,
    exchange_code,
    generate_pkce,
    generate_state,
)


@pytest.fixture
def settings() -> Settings:
    return Settings(
        tenant_id="00000000-0000-0000-0000-000000000001",
        client_id="00000000-0000-0000-0000-000000000002",
        sharepoint_site_url="https://contoso.sharepoint.cn/sites/demo",
        redirect_uri="http://localhost:8400/callback",
    )


class FakeCallback(AbstractContextManager["FakeCallback"]):
    def __init__(self, result: CallbackResult, events: list[str]) -> None:
        self.result = result
        self.events = events

    def __enter__(self) -> Self:
        self.events.append("callback-enter")
        return self

    def __exit__(self, *args: object) -> None:
        self.events.append("callback-exit")

    def wait(self, timeout_seconds: float) -> CallbackResult:
        self.events.append(f"callback-wait:{timeout_seconds}")
        return self.result


def invoke_callback_handler(path: str) -> tuple[CallbackResult | None, bytes, int]:
    results: list[CallbackResult] = []
    handler_type = oauth_pkce._build_callback_handler("/callback", results.append)
    handler = handler_type.__new__(handler_type)
    handler.path = path
    handler.wfile = BytesIO()
    statuses: list[int] = []
    handler.send_response = statuses.append
    handler.send_header = lambda *_: None
    handler.end_headers = lambda: None

    handler.do_GET()

    return (results[0] if results else None, handler.wfile.getvalue(), statuses[0])


def test_callback_handler_accepts_expected_path_and_hides_sensitive_values() -> None:
    result, body, status = invoke_callback_handler(
        "/callback?code=abc&state=expected&token=secret&verifier=private"
    )

    assert result == CallbackResult("abc", "expected", None, None)
    assert status == 200
    assert b"abc" not in body
    assert b"expected" not in body
    assert b"secret" not in body
    assert b"private" not in body


def test_callback_handler_parses_sanitized_oauth_error() -> None:
    result, body, status = invoke_callback_handler(
        "/callback?error=access_denied&error_description=Denied&state=expected"
    )

    assert result == CallbackResult(None, "expected", "access_denied", "Denied")
    assert status == 200
    assert b"access_denied" not in body
    assert b"Denied" not in body
    assert b"expected" not in body


def test_callback_handler_rejects_unexpected_path_without_completing_callback() -> None:
    result, body, status = invoke_callback_handler(
        "/wrong?code=abc&state=expected"
    )

    assert result is None
    assert status == 404
    assert b"abc" not in body
    assert b"expected" not in body


def test_loopback_callback_server_ignores_wrong_path_then_accepts_callback() -> None:
    expected = CallbackResult("abc", "expected", None, None)

    class FakeServer:
        def __init__(self) -> None:
            self.timeout: float | None = None
            self.timeouts: list[float | None] = []
            self.request_results: list[CallbackResult | None] = [None, expected]
            self.handled_requests = 0
            self.closed = False
            self.on_result = lambda result: None

        def handle_request(self) -> None:
            self.handled_requests += 1
            self.timeouts.append(self.timeout)
            result = self.request_results.pop(0)
            if result is not None:
                self.on_result(result)

        def server_close(self) -> None:
            self.closed = True

    fake_server = FakeServer()
    with (
        patch.object(oauth_pkce, "HTTPServer", return_value=fake_server),
        patch.object(oauth_pkce, "monotonic", side_effect=[100.0, 100.0, 100.0]),
    ):
        with LoopbackCallbackServer("http://127.0.0.1:8400/callback") as callback:
            fake_server.on_result = callback._store_result
            result = callback.wait(timeout_seconds=2)

    assert result == expected
    assert fake_server.handled_requests == 2
    assert fake_server.timeouts == [2.0, 2.0]
    assert fake_server.closed is True


def test_loopback_callback_server_raises_safe_timeout_and_closes() -> None:
    fake_server = type(
        "FakeServer",
        (),
        {
            "timeout": None,
            "handle_request": lambda self: None,
            "server_close": lambda self: setattr(self, "closed", True),
        },
    )()
    fake_server.closed = False

    with (
        patch.object(oauth_pkce, "HTTPServer", return_value=fake_server),
        patch.object(
            oauth_pkce,
            "monotonic",
            side_effect=[100.0, 100.0, 101.0],
            create=True,
        ) as monotonic,
    ):
        with pytest.raises(AuthError, match="等待登录回调超时"):
            with LoopbackCallbackServer("http://127.0.0.1:8400/callback") as callback:
                callback.wait(timeout_seconds=1)

    assert fake_server.timeout == 1
    assert monotonic.call_count == 3
    assert fake_server.closed is True


def test_authenticate_starts_callback_before_opening_gallatin_browser_url(
    settings: Settings,
) -> None:
    events: list[str] = []
    session = requests.Session()
    callback = FakeCallback(
        CallbackResult("authorization-code", "expected-state", None, None), events
    )

    def open_browser(url: str) -> bool:
        events.append("browser-open")
        assert urlsplit(url).netloc == "login.partner.microsoftonline.cn"
        return True

    def callback_factory(redirect_uri: str) -> FakeCallback:
        assert redirect_uri == settings.redirect_uri
        return callback

    with (
        patch.object(oauth_pkce, "generate_pkce", return_value=PkcePair("verifier", "challenge")),
        patch.object(oauth_pkce, "generate_state", return_value="expected-state"),
        patch.object(oauth_pkce, "exchange_code", return_value="access-token") as exchange,
    ):
        token = authenticate(
            settings,
            session,
            browser_open=open_browser,
            callback_factory=callback_factory,
        )

    assert events == [
        "callback-enter",
        "browser-open",
        "callback-wait:180",
        "callback-exit",
    ]
    exchange.assert_called_once_with(settings, "authorization-code", "verifier", session)
    assert token == "access-token"


def test_authenticate_rejects_browser_open_failure(settings: Settings) -> None:
    events: list[str] = []
    callback = FakeCallback(CallbackResult(None, None, None, None), events)

    with (
        patch.object(oauth_pkce, "generate_pkce", return_value=PkcePair("verifier", "challenge")),
        patch.object(oauth_pkce, "generate_state", return_value="expected-state"),
        patch.object(oauth_pkce, "exchange_code") as exchange,
        pytest.raises(AuthError, match="无法打开系统浏览器"),
    ):
        authenticate(
            settings,
            requests.Session(),
            browser_open=lambda _: False,
            callback_factory=lambda redirect_uri: callback,
        )

    assert events == ["callback-enter", "callback-exit"]
    exchange.assert_not_called()


@pytest.mark.parametrize(
    "result",
    [
        CallbackResult("authorization-code", None, None, None),
        CallbackResult("authorization-code", "wrong-state", None, None),
        CallbackResult(None, "expected-state", None, None),
    ],
)
def test_authenticate_rejects_invalid_callback_before_exchange(
    settings: Settings, result: CallbackResult
) -> None:
    callback = FakeCallback(result, [])

    with (
        patch.object(oauth_pkce, "generate_pkce", return_value=PkcePair("verifier", "challenge")),
        patch.object(oauth_pkce, "generate_state", return_value="expected-state"),
        patch.object(oauth_pkce.secrets, "compare_digest", wraps=oauth_pkce.secrets.compare_digest) as compare,
        patch.object(oauth_pkce, "exchange_code") as exchange,
        pytest.raises(AuthError),
    ):
        authenticate(
            settings,
            requests.Session(),
            browser_open=lambda _: True,
            callback_factory=lambda redirect_uri: callback,
        )

    if result.state is not None:
        compare.assert_called_once_with(result.state, "expected-state")
    else:
        compare.assert_not_called()
    exchange.assert_not_called()


def test_authenticate_surfaces_access_denied_without_sensitive_callback_data(
    settings: Settings,
) -> None:
    callback = FakeCallback(
        CallbackResult("authorization-code", "expected-state", "access_denied", "Denied"),
        [],
    )

    with (
        patch.object(oauth_pkce, "generate_pkce", return_value=PkcePair("verifier", "challenge")),
        patch.object(oauth_pkce, "generate_state", return_value="expected-state"),
        patch.object(oauth_pkce, "exchange_code") as exchange,
        pytest.raises(AuthError) as caught,
    ):
        authenticate(
            settings,
            requests.Session(),
            browser_open=lambda _: True,
            callback_factory=lambda redirect_uri: callback,
        )

    assert "access_denied" in str(caught.value)
    assert "authorization-code" not in str(caught.value)
    assert "Denied" not in str(caught.value)
    exchange.assert_not_called()


@pytest.mark.parametrize(
    ("callback_state", "expected_message", "compare_calls"),
    [
        (None, "登录回调缺少状态参数", 0),
        ("forged-state", "登录回调状态不匹配", 1),
    ],
)
def test_authenticate_rejects_oauth_error_until_state_is_validated(
    settings: Settings,
    callback_state: str | None,
    expected_message: str,
    compare_calls: int,
) -> None:
    callback = FakeCallback(
        CallbackResult(
            "authorization-code",
            callback_state,
            "access_denied",
            "private error description",
        ),
        [],
    )

    with (
        patch.object(oauth_pkce, "generate_pkce", return_value=PkcePair("verifier", "challenge")),
        patch.object(oauth_pkce, "generate_state", return_value="expected-state"),
        patch.object(oauth_pkce.secrets, "compare_digest", wraps=oauth_pkce.secrets.compare_digest) as compare,
        patch.object(oauth_pkce, "exchange_code") as exchange,
        pytest.raises(AuthError) as caught,
    ):
        authenticate(
            settings,
            requests.Session(),
            browser_open=lambda _: True,
            callback_factory=lambda redirect_uri: callback,
        )

    assert str(caught.value) == expected_message
    assert "access_denied" not in str(caught.value)
    assert "authorization-code" not in str(caught.value)
    assert "private error description" not in str(caught.value)
    assert compare.call_count == compare_calls
    exchange.assert_not_called()


def test_generate_pkce_uses_s256_base64url_without_padding() -> None:
    verifier = "fixed-pkce-verifier_~value"
    expected_challenge = (
        base64.urlsafe_b64encode(hashlib.sha256(verifier.encode("ascii")).digest())
        .rstrip(b"=")
        .decode("ascii")
    )

    with patch("secrets.token_urlsafe", return_value=verifier) as token_urlsafe:
        pair = generate_pkce()

    token_urlsafe.assert_called_once_with(64)
    assert pair.verifier == verifier
    assert pair.challenge == expected_challenge
    assert "=" not in pair.challenge


def test_generate_state_uses_cryptographically_secure_random_value() -> None:
    with patch("secrets.token_urlsafe", return_value="fixed-state") as token_urlsafe:
        state = generate_state()

    token_urlsafe.assert_called_once_with(32)
    assert state == "fixed-state"


def test_authorization_url_contains_exact_gallatin_oauth_parameters(
    settings: Settings,
) -> None:
    url = build_authorization_url(settings, "expected-state", "expected-challenge")
    parsed = urlsplit(url)
    query = parse_qs(parsed.query)

    assert SCOPES == (
        "openid",
        "profile",
        "User.Read",
        "Sites.Read.All",
        "Files.ReadWrite.All",
    )
    assert f"{parsed.scheme}://{parsed.netloc}{parsed.path}" == settings.authorize_endpoint
    assert query["client_id"] == [settings.client_id]
    assert query["response_type"] == ["code"]
    assert query["response_mode"] == ["query"]
    assert query["redirect_uri"] == [settings.redirect_uri]
    assert query["scope"] == [
        "openid profile User.Read Sites.Read.All Files.ReadWrite.All"
    ]
    assert query["state"] == ["expected-state"]
    assert query["code_challenge"] == ["expected-challenge"]
    assert query["code_challenge_method"] == ["S256"]
    assert "offline_access" not in query["scope"][0]


@responses.activate
def test_exchange_code_posts_exact_public_client_form_and_returns_only_token(
    settings: Settings,
) -> None:
    responses.post(
        settings.token_endpoint,
        json={"access_token": "access-token", "refresh_token": "must-not-return"},
        status=200,
        match=[
            matchers.urlencoded_params_matcher(
                {
                    "grant_type": "authorization_code",
                    "client_id": settings.client_id,
                    "code": "authorization-code",
                    "redirect_uri": settings.redirect_uri,
                    "code_verifier": "pkce-verifier",
                }
            )
        ],
    )
    session = requests.Session()

    with patch.object(session, "post", wraps=session.post) as post:
        token = exchange_code(settings, "authorization-code", "pkce-verifier", session)

    assert token == "access-token"
    post.assert_called_once_with(
        settings.token_endpoint,
        data={
            "grant_type": "authorization_code",
            "client_id": settings.client_id,
            "code": "authorization-code",
            "redirect_uri": settings.redirect_uri,
            "code_verifier": "pkce-verifier",
        },
        timeout=HTTP_TIMEOUT,
    )
    request_body = responses.calls[0].request.body
    assert request_body is not None
    assert "client_secret" not in request_body


@responses.activate
def test_exchange_code_sanitizes_oauth_error_json(settings: Settings) -> None:
    responses.post(
        settings.token_endpoint,
        json={
            "error": "invalid_grant",
            "error_description": "super-secret-token",
        },
        status=400,
    )

    with pytest.raises(AuthError) as caught:
        exchange_code(settings, "authorization-code", "pkce-verifier", requests.Session())

    assert "super-secret-token" not in str(caught.value)


@responses.activate
def test_exchange_code_translates_non_json_response(settings: Settings) -> None:
    responses.post(
        settings.token_endpoint,
        body="upstream response must stay private",
        content_type="text/plain",
        status=502,
    )

    with pytest.raises(AuthError) as caught:
        exchange_code(settings, "authorization-code", "pkce-verifier", requests.Session())

    assert "upstream response must stay private" not in str(caught.value)


@responses.activate
def test_exchange_code_rejects_success_without_access_token(settings: Settings) -> None:
    responses.post(settings.token_endpoint, json={"token_type": "Bearer"}, status=200)

    with pytest.raises(AuthError):
        exchange_code(settings, "authorization-code", "pkce-verifier", requests.Session())


@responses.activate
def test_exchange_code_translates_transport_failure(settings: Settings) -> None:
    responses.post(settings.token_endpoint, body=requests.ConnectionError("private detail"))

    with pytest.raises(AuthError) as caught:
        exchange_code(settings, "authorization-code", "pkce-verifier", requests.Session())

    assert "private detail" not in str(caught.value)
