import os
import re
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import unquote_to_bytes, urlsplit, urlunsplit
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
            raise ConfigError(f"缺少必填配置 {key}；请检查 .env 或环境变量")
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
        raise ConfigError(f"配置 {key} 必须是有效的 UUID") from exc


def _validate_and_normalize_site_url(value: str) -> str:
    error_message = (
        "SharePoint 站点 URL 无效：SHAREPOINT_SITE_URL 必须使用 HTTPS、"
        "小写 sharepoint.cn 主机，且不能包含 query 或 fragment"
    )
    try:
        parsed = urlsplit(value)
        hostname = parsed.hostname or ""
        parsed.port
        username = parsed.username
        password = parsed.password
    except ValueError as exc:
        raise ConfigError(error_message) from exc

    hostname_in_url = parsed.netloc.rsplit("@", 1)[-1].split(":", 1)[0]
    valid = (
        parsed.scheme == "https"
        and hostname_in_url == hostname_in_url.lower()
        and hostname.endswith(".sharepoint.cn")
        and not parsed.query
        and not parsed.fragment
        and username is None
        and password is None
    )
    if not valid:
        raise ConfigError(error_message)

    raw_path = parsed.path
    if re.search(r"%(?![0-9A-Fa-f]{2})", raw_path):
        raise ConfigError("SharePoint 站点 URL 包含无效的百分号编码")
    if re.search(r"%2f", raw_path, flags=re.IGNORECASE):
        raise ConfigError(
            "SharePoint 站点 URL 的路径段不能包含编码斜杠 %2F；请使用真实层级路径"
        )
    try:
        decoded_path = unquote_to_bytes(raw_path).decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ConfigError("SharePoint 站点 URL 包含无效的 UTF-8 百分号编码") from exc

    return urlunsplit(
        (
            parsed.scheme,
            parsed.netloc,
            decoded_path.removesuffix("/"),
            "",
            "",
        )
    )


def _validate_redirect_uri(value: str) -> str:
    try:
        parsed = urlsplit(value)
        port = parsed.port
    except ValueError as exc:
        raise ConfigError(
            "登录回调配置 REDIRECT_URI 无效：必须是带显式端口和非根路径的 "
            "HTTP loopback URI"
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
            "登录回调配置 REDIRECT_URI 无效：必须使用 localhost 或 127.0.0.1，"
            "包含显式端口和非根路径，且不能包含 query 或 fragment"
        )
    return value
