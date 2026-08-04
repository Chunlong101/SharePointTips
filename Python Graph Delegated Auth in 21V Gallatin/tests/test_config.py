from pathlib import Path

import pytest

from src.config import Settings, load_settings
from src.errors import (
    AuthError,
    ConfigError,
    DemoError,
    ExitCode,
    GraphError,
    LocalFileError,
)


VALID_ENV = {
    "TENANT_ID": "00000000-0000-0000-0000-000000000001",
    "CLIENT_ID": "00000000-0000-0000-0000-000000000002",
    "SHAREPOINT_SITE_URL": "https://contoso.sharepoint.cn/sites/演示 Site",
    "REDIRECT_URI": "http://localhost:8400/callback",
}


def test_settings_exposes_gallatin_site_and_oauth_properties(tmp_path: Path) -> None:
    settings = load_settings(tmp_path / "missing.env", VALID_ENV)

    assert settings == Settings(
        tenant_id=VALID_ENV["TENANT_ID"],
        client_id=VALID_ENV["CLIENT_ID"],
        sharepoint_site_url=VALID_ENV["SHAREPOINT_SITE_URL"],
        redirect_uri=VALID_ENV["REDIRECT_URI"],
    )
    assert settings.site_hostname == "contoso.sharepoint.cn"
    assert settings.site_path == "/sites/演示 Site"
    assert settings.authorize_endpoint == (
        "https://login.partner.microsoftonline.cn/"
        "00000000-0000-0000-0000-000000000001/oauth2/v2.0/authorize"
    )
    assert settings.token_endpoint == (
        "https://login.partner.microsoftonline.cn/"
        "00000000-0000-0000-0000-000000000001/oauth2/v2.0/token"
    )


@pytest.mark.parametrize("key", VALID_ENV)
@pytest.mark.parametrize("value", [None, ""])
def test_missing_or_empty_required_setting_mentions_key(
    tmp_path: Path, key: str, value: str | None
) -> None:
    environ = dict(VALID_ENV)
    if value is None:
        environ.pop(key)
    else:
        environ[key] = value

    with pytest.raises(ConfigError, match=key):
        load_settings(tmp_path / "missing.env", environ)


@pytest.mark.parametrize(
    "site_url",
    [
        "http://contoso.sharepoint.cn/sites/demo",
        "https://contoso.sharepoint.com/sites/demo",
        "https://example.cn/sites/demo",
    ],
)
def test_invalid_sharepoint_site_url_mentions_required_domain(
    tmp_path: Path, site_url: str
) -> None:
    environ = {**VALID_ENV, "SHAREPOINT_SITE_URL": site_url}

    with pytest.raises(ConfigError, match="sharepoint\\.cn"):
        load_settings(tmp_path / "missing.env", environ)


@pytest.mark.parametrize(
    "redirect_uri",
    [
        "https://localhost:8400/callback",
        "http://example.com:8400/callback",
        "http://localhost/callback",
    ],
)
def test_invalid_redirect_uri_mentions_setting(
    tmp_path: Path, redirect_uri: str
) -> None:
    environ = {**VALID_ENV, "REDIRECT_URI": redirect_uri}

    with pytest.raises(ConfigError, match="REDIRECT_URI"):
        load_settings(tmp_path / "missing.env", environ)


def test_environment_overrides_dotenv_and_site_trailing_slash_is_removed(
    tmp_path: Path,
) -> None:
    env_file = tmp_path / ".env"
    env_file.write_text(
        "TENANT_ID=ffffffff-ffff-ffff-ffff-ffffffffffff\n"
        "CLIENT_ID=ffffffff-ffff-ffff-ffff-ffffffffffff\n"
        "SHAREPOINT_SITE_URL=https://wrong.sharepoint.cn/sites/wrong\n"
        "REDIRECT_URI=http://localhost:9999/wrong\n",
        encoding="utf-8",
    )
    environ = {**VALID_ENV, "SHAREPOINT_SITE_URL": f'{VALID_ENV["SHAREPOINT_SITE_URL"]}/'}

    settings = load_settings(env_file, environ)

    assert settings.tenant_id == VALID_ENV["TENANT_ID"]
    assert settings.sharepoint_site_url == VALID_ENV["SHAREPOINT_SITE_URL"]
    assert settings.site_path == "/sites/演示 Site"


@pytest.mark.parametrize(
    ("encoded_path", "decoded_path"),
    [
        ("/sites/Demo%20Site", "/sites/Demo Site"),
        ("/sites/%E6%BC%94%E7%A4%BA%20Site", "/sites/演示 Site"),
        ("/sites/Demo%2520Site", "/sites/Demo%20Site"),
    ],
)
def test_site_path_is_percent_decoded_exactly_once(
    tmp_path: Path, encoded_path: str, decoded_path: str
) -> None:
    settings = load_settings(
        tmp_path / "missing.env",
        {
            **VALID_ENV,
            "SHAREPOINT_SITE_URL": f"https://contoso.sharepoint.cn{encoded_path}",
        },
    )

    assert settings.site_path == decoded_path
    assert settings.sharepoint_site_url == (
        f"https://contoso.sharepoint.cn{decoded_path}"
    )


@pytest.mark.parametrize(
    "site_url",
    [
        "https://contoso.sharepoint.cn/sites/Demo%2FSite",
        "https://contoso.sharepoint.cn/sites/Demo%2fSite",
        "https://contoso.sharepoint.cn/sites/Demo%",
        "https://contoso.sharepoint.cn/sites/Demo%2",
        "https://contoso.sharepoint.cn/sites/Demo%GG",
        "https://contoso.sharepoint.cn/sites/%FF",
    ],
)
def test_site_url_rejects_ambiguous_or_malformed_percent_encoding(
    tmp_path: Path, site_url: str
) -> None:
    with pytest.raises(ConfigError, match="站点 URL"):
        load_settings(
            tmp_path / "missing.env",
            {**VALID_ENV, "SHAREPOINT_SITE_URL": site_url},
        )


def test_missing_configuration_message_is_chinese_and_actionable(tmp_path: Path) -> None:
    environ = dict(VALID_ENV)
    environ.pop("TENANT_ID")

    with pytest.raises(ConfigError) as caught:
        load_settings(tmp_path / "missing.env", environ)

    assert str(caught.value) == "缺少必填配置 TENANT_ID；请检查 .env 或环境变量"


@pytest.mark.parametrize("key", ["TENANT_ID", "CLIENT_ID"])
def test_invalid_uuid_mentions_key(tmp_path: Path, key: str) -> None:
    environ = {**VALID_ENV, key: "not-a-uuid"}

    with pytest.raises(ConfigError, match=key):
        load_settings(tmp_path / "missing.env", environ)


@pytest.mark.parametrize(
    "site_url",
    [
        "https://contoso.sharepoint.cn/sites/demo?x=1",
        "https://contoso.sharepoint.cn/sites/demo#fragment",
        "https://CONTOSO.sharepoint.cn/sites/demo",
    ],
)
def test_other_invalid_sharepoint_urls_mention_required_domain(
    tmp_path: Path, site_url: str
) -> None:
    environ = {**VALID_ENV, "SHAREPOINT_SITE_URL": site_url}

    with pytest.raises(ConfigError, match="sharepoint\\.cn"):
        load_settings(tmp_path / "missing.env", environ)


@pytest.mark.parametrize(
    "site_url",
    [
        "https://contoso.sharepoint.cn:not-a-port/sites/demo",
        "https://[contoso.sharepoint.cn/sites/demo",
    ],
)
def test_malformed_sharepoint_url_raises_config_error(
    tmp_path: Path, site_url: str
) -> None:
    environ = {**VALID_ENV, "SHAREPOINT_SITE_URL": site_url}

    with pytest.raises(ConfigError, match="SHAREPOINT_SITE_URL"):
        load_settings(tmp_path / "missing.env", environ)


@pytest.mark.parametrize(
    "redirect_uri",
    [
        "http://127.0.0.1:8400",
        "http://127.0.0.1:8400/",
        "http://127.0.0.1:8400/callback?x=1",
        "http://127.0.0.1:8400/callback#fragment",
    ],
)
def test_other_invalid_redirect_uris_mention_setting(
    tmp_path: Path, redirect_uri: str
) -> None:
    environ = {**VALID_ENV, "REDIRECT_URI": redirect_uri}

    with pytest.raises(ConfigError, match="REDIRECT_URI"):
        load_settings(tmp_path / "missing.env", environ)


def test_malformed_redirect_uri_raises_config_error(tmp_path: Path) -> None:
    environ = {**VALID_ENV, "REDIRECT_URI": "http://[localhost:8400/callback"}

    with pytest.raises(ConfigError, match="REDIRECT_URI"):
        load_settings(tmp_path / "missing.env", environ)


def test_demo_errors_expose_safe_message_and_matching_exit_codes() -> None:
    assert str(DemoError("safe message")) == "safe message"
    assert DemoError.exit_code == ExitCode.UNEXPECTED
    assert ConfigError.exit_code == ExitCode.CONFIG
    assert AuthError.exit_code == ExitCode.AUTH
    assert GraphError.exit_code == ExitCode.GRAPH
    assert LocalFileError.exit_code == ExitCode.LOCAL_FILE
    assert list(ExitCode) == [
        ExitCode.OK,
        ExitCode.UNEXPECTED,
        ExitCode.USAGE,
        ExitCode.CONFIG,
        ExitCode.AUTH,
        ExitCode.GRAPH,
        ExitCode.LOCAL_FILE,
    ]
    assert [code.value for code in ExitCode] == [0, 1, 2, 10, 20, 30, 40]
