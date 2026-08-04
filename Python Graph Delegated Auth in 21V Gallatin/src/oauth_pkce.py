import base64
import hashlib
import secrets
import webbrowser
from collections.abc import Callable
from contextlib import AbstractContextManager
from dataclasses import dataclass
from http.server import BaseHTTPRequestHandler, HTTPServer
from time import monotonic
from typing import ContextManager
from urllib.parse import parse_qs, urlencode, urlsplit

import requests

from .config import Settings
from .errors import AuthError


SCOPES = ("openid", "profile", "User.Read", "Sites.Read.All", "Files.ReadWrite.All")
HTTP_TIMEOUT = (10, 30)


@dataclass(frozen=True)
class PkcePair:
    verifier: str
    challenge: str


@dataclass(frozen=True)
class CallbackResult:
    code: str | None
    state: str | None
    error: str | None
    error_description: str | None


def _build_callback_handler(
    expected_path: str,
    on_result: Callable[[CallbackResult], None],
) -> type[BaseHTTPRequestHandler]:
    result_consumer = on_result

    class CallbackHandler(BaseHTTPRequestHandler):
        on_result = staticmethod(result_consumer)

        def do_GET(self) -> None:
            parsed = urlsplit(self.path)
            if parsed.path != expected_path:
                self._send_html(404, "Callback path not found.")
                return

            query = parse_qs(parsed.query)
            self.on_result(
                CallbackResult(
                    code=_first_query_value(query, "code"),
                    state=_first_query_value(query, "state"),
                    error=_first_query_value(query, "error"),
                    error_description=_first_query_value(query, "error_description"),
                )
            )
            self._send_html(200, "Authentication completed. You may close this window.")

        def _send_html(self, status: int, message: str) -> None:
            body = (
                "<!doctype html><html><head><meta charset=\"utf-8\"></head>"
                f"<body><p>{message}</p></body></html>"
            ).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, format: str, *args: object) -> None:
            return

    return CallbackHandler


def _first_query_value(query: dict[str, list[str]], name: str) -> str | None:
    values = query.get(name)
    return values[0] if values else None


class LoopbackCallbackServer(AbstractContextManager["LoopbackCallbackServer"]):
    def __init__(self, redirect_uri: str) -> None:
        parsed = urlsplit(redirect_uri)
        host = parsed.hostname or ""
        port = parsed.port
        if not host or port is None:
            raise AuthError("登录回调地址无效")

        self._result: CallbackResult | None = None
        handler_type = _build_callback_handler(parsed.path, self._store_result)
        self._server = HTTPServer((host, port), handler_type)

    def _store_result(self, result: CallbackResult) -> None:
        self._result = result

    def wait(self, timeout_seconds: float) -> CallbackResult:
        deadline = monotonic() + timeout_seconds
        while self._result is None:
            remaining = deadline - monotonic()
            if remaining <= 0:
                raise AuthError("等待登录回调超时")
            self._server.timeout = remaining
            self._server.handle_request()
        return self._result

    def __exit__(self, *args: object) -> None:
        self._server.server_close()


def generate_pkce() -> PkcePair:
    verifier = secrets.token_urlsafe(64)
    digest = hashlib.sha256(verifier.encode("ascii")).digest()
    challenge = base64.urlsafe_b64encode(digest).rstrip(b"=").decode("ascii")
    return PkcePair(verifier, challenge)


def generate_state() -> str:
    return secrets.token_urlsafe(32)


def build_authorization_url(settings: Settings, state: str, challenge: str) -> str:
    query = urlencode(
        {
            "client_id": settings.client_id,
            "response_type": "code",
            "response_mode": "query",
            "redirect_uri": settings.redirect_uri,
            "scope": " ".join(SCOPES),
            "state": state,
            "code_challenge": challenge,
            "code_challenge_method": "S256",
        }
    )
    return f"{settings.authorize_endpoint}?{query}"


def exchange_code(
    settings: Settings,
    code: str,
    verifier: str,
    session: requests.Session,
) -> str:
    data = {
        "grant_type": "authorization_code",
        "client_id": settings.client_id,
        "code": code,
        "redirect_uri": settings.redirect_uri,
        "code_verifier": verifier,
    }
    try:
        response = session.post(settings.token_endpoint, data=data, timeout=HTTP_TIMEOUT)
    except requests.RequestException as exc:
        raise AuthError("Token request failed") from exc

    try:
        payload = response.json()
    except ValueError as exc:
        raise AuthError("Token endpoint returned an invalid response") from exc

    if not response.ok:
        raise AuthError("Token endpoint rejected the authorization code")

    access_token = payload.get("access_token") if isinstance(payload, dict) else None
    if not isinstance(access_token, str) or not access_token:
        raise AuthError("Token endpoint response did not contain an access token")
    return access_token


def authenticate(
    settings: Settings,
    session: requests.Session,
    browser_open: Callable[[str], bool] = webbrowser.open,
    callback_factory: Callable[[str], ContextManager] = LoopbackCallbackServer,
) -> str:
    pkce = generate_pkce()
    state = generate_state()
    with callback_factory(settings.redirect_uri) as callback:
        url = build_authorization_url(settings, state, pkce.challenge)
        if not browser_open(url):
            raise AuthError("无法打开系统浏览器")
        result = callback.wait(timeout_seconds=180)

    if not result.state:
        raise AuthError("登录回调缺少状态参数")
    if not secrets.compare_digest(result.state, state):
        raise AuthError("登录回调状态不匹配")
    if result.error:
        message = (
            "登录授权失败: access_denied"
            if result.error == "access_denied"
            else "登录授权失败"
        )
        raise AuthError(message)
    if not result.code:
        raise AuthError("登录回调缺少必要参数")
    return exchange_code(settings, result.code, pkce.verifier, session)
