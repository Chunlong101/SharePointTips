import base64
import hashlib
from unittest.mock import patch
from urllib.parse import parse_qs, urlsplit

import pytest
import requests
import responses
from responses import matchers

from src.config import Settings
from src.errors import AuthError
from src.oauth_pkce import (
    HTTP_TIMEOUT,
    SCOPES,
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
