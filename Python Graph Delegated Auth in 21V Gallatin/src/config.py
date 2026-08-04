import os
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlsplit
from uuid import UUID

from dotenv import dotenv_values

from .errors import ConfigError


_REQUIRED_KEYS = (
    "TENANT_ID",
    "CLIENT_ID",
    "SHAREPOINT_SITE_URL",
    "REDIRECT_URI",
)


@dataclass(frozen=True)
class Settings:
    tenant_id: str
    client_id: str
    sharepoint_site_url: str
    redirect_uri: str

    @property
    def site_hostname(self) -> str:
        return urlsplit(self.sharepoint_site_url).hostname or ""

    @property
    def site_path(self) -> str:
        return urlsplit(self.sharepoint_site_url).path

    @property
    def authorize_endpoint(self) -> str:
        return (
            "https://login.partner.microsoftonline.cn/"
            f"{self.tenant_id}/oauth2/v2.0/authorize"
        )

    @property
    def token_endpoint(self) -> str:
        return (
            "https://login.partner.microsoftonline.cn/"
            f"{self.tenant_id}/oauth2/v2.0/token"
        )


def load_settings(
    env_file: str | Path = ".env",
    environ: Mapping[str, str] | None = None,
) -> Settings:
    values = dict(dotenv_values(env_file))
    values.update(os.environ if environ is None else environ)

    required = {}
    for key in _REQUIRED_KEYS:
        value = values.get(key)
        if value is None or not value.strip():
            raise ConfigError(f"Missing or empty required setting: {key}")
        required[key] = value.strip()

    _validate_uuid(required["TENANT_ID"], "TENANT_ID")
    _validate_uuid(required["CLIENT_ID"], "CLIENT_ID")

    site_url = _validate_and_normalize_site_url(required["SHAREPOINT_SITE_URL"])
    redirect_uri = _validate_redirect_uri(required["REDIRECT_URI"])

    return Settings(
        tenant_id=required["TENANT_ID"],
        client_id=required["CLIENT_ID"],
        sharepoint_site_url=site_url,
        redirect_uri=redirect_uri,
    )


def _validate_uuid(value: str, key: str) -> None:
    try:
        UUID(value)
    except (ValueError, AttributeError) as exc:
        raise ConfigError(f"{key} must be a valid UUID") from exc


def _validate_and_normalize_site_url(value: str) -> str:
    parsed = urlsplit(value)
    hostname = parsed.hostname or ""
    hostname_in_url = parsed.netloc.rsplit("@", 1)[-1].split(":", 1)[0]
    valid = (
        parsed.scheme == "https"
        and hostname_in_url == hostname_in_url.lower()
        and hostname.endswith(".sharepoint.cn")
        and not parsed.query
        and not parsed.fragment
        and parsed.username is None
        and parsed.password is None
    )
    if not valid:
        raise ConfigError(
            "SHAREPOINT_SITE_URL must be an HTTPS URL on a lowercase sharepoint.cn host "
            "without a query or fragment"
        )
    return value.removesuffix("/")


def _validate_redirect_uri(value: str) -> str:
    parsed = urlsplit(value)
    try:
        port = parsed.port
    except ValueError as exc:
        raise ConfigError(
            "REDIRECT_URI must be an HTTP loopback URI with an explicit port and "
            "non-root callback path"
        ) from exc

    valid = (
        parsed.scheme == "http"
        and parsed.hostname in {"localhost", "127.0.0.1"}
        and port is not None
        and parsed.path not in {"", "/"}
        and not parsed.query
        and not parsed.fragment
        and parsed.username is None
        and parsed.password is None
    )
    if not valid:
        raise ConfigError(
            "REDIRECT_URI must be an HTTP loopback URI with an explicit port and "
            "non-root callback path, without a query or fragment"
        )
    return value
