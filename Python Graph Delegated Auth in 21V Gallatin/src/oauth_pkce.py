import base64
import hashlib
import secrets
from dataclasses import dataclass
from urllib.parse import urlencode

import requests

from .config import Settings
from .errors import AuthError


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
