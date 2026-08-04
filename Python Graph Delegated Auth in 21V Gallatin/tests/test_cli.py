import io
import os
from pathlib import Path
import subprocess
import sys

import pytest

import main as cli
from src.errors import AuthError, ConfigError, GraphError, LocalFileError


FAKE_TOKEN = "fake-access-token-must-never-be-printed"

PROJECT_ROOT = Path(__file__).resolve().parents[1]
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
    "If-None-Match: *",
    "os.link()",
    "os.replace()",
    "250 * 1024 * 1024",
    "百分号编码只解码一次",
    "编码斜杠 `%2F`",
    "令牌兑换不会跟随 HTTP 重定向",
    "初始下载 GET",
    "响应正文开始消费后不会重试",
    "端口绑定和浏览器启动异常均返回退出码 `20`",
]


class FakeSession:
    def __init__(self):
        self.closed = False

    def close(self):
        self.closed = True


@pytest.mark.parametrize("required_text", REQUIRED_DOC_TEXT)
def test_documentation_contains_required_setup_and_cli_text(required_text):
    readme = (PROJECT_ROOT / "README.md").read_text(encoding="utf-8")

    assert required_text in readme


def test_documentation_qualifies_conditional_upload_guarantee():
    readme = (PROJECT_ROOT / "README.md").read_text(encoding="utf-8")

    for caveat in (
        "防御性条件请求",
        "官方简单上传文档没有明确保证",
        "真实 Gallatin 租户验证",
        "不构成硬性并发保证",
        "409/412 的映射仅在服务遵守条件头时适用",
    ):
        assert caveat in readme

    assert "不会静默覆盖并发胜者" not in readme


def test_documentation_explains_redirect_download_proxy_boundary():
    readme = (PROJECT_ROOT / "README.md").read_text(encoding="utf-8")

    for caveat in (
        "全新的凭据隔离 session",
        "trust_env=False",
        "不会继承环境代理、cookie 或 auth",
        "直接 HTTPS 连接",
        "强制代理环境",
        "经过单独安全评审的显式代理支持",
        "保持凭据隔离",
    ):
        assert caveat in readme


def test_documentation_env_example_has_only_public_configuration():
    env_example = (PROJECT_ROOT / ".env.example").read_text(encoding="utf-8")

    for key in (
        "TENANT_ID",
        "CLIENT_ID",
        "SHAREPOINT_SITE_URL",
        "REDIRECT_URI",
    ):
        assert f"{key}=" in env_example
    for forbidden_name in ("CLIENT_SECRET", "ACCESS_TOKEN", "PASSWORD"):
        assert forbidden_name not in env_example.upper()


class FakeGraphClient:
    def __init__(self):
        self.calls = []
        self.user = {
            "id": "secret-object-id",
            "displayName": "示例用户",
            "userPrincipalName": "user@contoso.partner.onmschina.cn",
        }
        self.items = []

    def get_current_user(self):
        self.calls.append(("get_current_user",))
        return self.user

    def resolve_default_drive(self, settings):
        self.calls.append(("resolve_default_drive", settings))
        return "site-id", "drive-id"

    def list_children(self, drive_id, folder=""):
        self.calls.append(("list_children", drive_id, folder))
        return self.items

    def upload_file(self, drive_id, source, destination, overwrite=False):
        self.calls.append(
            ("upload_file", drive_id, source, destination, overwrite)
        )
        return {"id": "uploaded-id"}

    def download_file(self, drive_id, source, destination, overwrite=False):
        self.calls.append(
            ("download_file", drive_id, source, destination, overwrite)
        )
        return destination


def make_dependencies(settings):
    session = FakeSession()
    graph = FakeGraphClient()
    auth_calls = []

    def fake_authenticate(actual_settings, actual_session):
        auth_calls.append((actual_settings, actual_session))
        return FAKE_TOKEN

    dependencies = cli.Dependencies(
        load_settings=lambda: settings,
        session_factory=lambda: session,
        authenticate=fake_authenticate,
        graph_client_factory=lambda token, actual_session: graph,
    )
    return dependencies, session, graph, auth_calls


@pytest.mark.parametrize(
    "arguments",
    [
        ["login"],
        ["list"],
        ["upload", "--source", "local.txt", "--destination", "remote.txt"],
        ["download", "--source", "remote.txt", "--destination", "local.txt"],
    ],
)
def test_every_valid_command_authenticates_exactly_once(settings, arguments):
    dependencies, session, _graph, auth_calls = make_dependencies(settings)
    args = cli.build_parser().parse_args(arguments)

    assert cli.run(args, dependencies) == 0

    assert auth_calls == [(settings, session)]
    assert session.closed is True


def test_login_prints_only_safe_user_fields_and_does_not_resolve_drive(
    settings, capsys
):
    dependencies, _session, graph, _auth_calls = make_dependencies(settings)

    assert cli.run(cli.build_parser().parse_args(["login"]), dependencies) == 0

    captured = capsys.readouterr()
    assert captured.out == (
        "显示名称: 示例用户\n"
        "用户主体名称: user@contoso.partner.onmschina.cn\n"
    )
    assert captured.err == ""
    assert "secret-object-id" not in captured.out
    assert FAKE_TOKEN not in captured.out
    assert graph.calls == [("get_current_user",)]


def test_list_resolves_drive_and_prints_all_item_fields(settings, capsys):
    dependencies, _session, graph, _auth_calls = make_dependencies(settings)
    graph.items = [
        {
            "folder": {"childCount": 2},
            "name": "文档",
            "size": 123,
            "lastModifiedDateTime": "2026-08-04T01:02:03Z",
            "webUrl": "https://contoso.sharepoint.cn/folder",
        },
        {"file": {}, "name": "report.txt"},
    ]
    args = cli.build_parser().parse_args(["list", "--folder", "Shared/Sub"])

    assert cli.run(args, dependencies) == 0

    captured = capsys.readouterr()
    assert captured.out == (
        "类型\t名称\t大小\t修改时间\tWeb URL\n"
        "DIR\t文档\t123\t2026-08-04T01:02:03Z\t"
        "https://contoso.sharepoint.cn/folder\n"
        "FILE\treport.txt\t-\t-\t-\n"
    )
    assert captured.err == ""
    assert FAKE_TOKEN not in captured.out
    assert graph.calls == [
        ("resolve_default_drive", settings),
        ("list_children", "drive-id", "Shared/Sub"),
    ]


def test_upload_passes_exact_paths_and_overwrite_flag(settings, capsys):
    dependencies, _session, graph, _auth_calls = make_dependencies(settings)
    args = cli.build_parser().parse_args(
        [
            "upload",
            "--source",
            "local file.txt",
            "--destination",
            "Folder/remote.txt",
            "--overwrite",
        ]
    )

    assert cli.run(args, dependencies) == 0

    assert graph.calls == [
        ("resolve_default_drive", settings),
        (
            "upload_file",
            "drive-id",
            Path("local file.txt"),
            "Folder/remote.txt",
            True,
        ),
    ]
    assert capsys.readouterr().out == "上传成功: Folder/remote.txt\n"


def test_download_passes_exact_paths_and_default_overwrite(settings, capsys):
    dependencies, _session, graph, _auth_calls = make_dependencies(settings)
    args = cli.build_parser().parse_args(
        [
            "download",
            "--source",
            "Folder/remote.txt",
            "--destination",
            "downloads/local file.txt",
        ]
    )

    assert cli.run(args, dependencies) == 0

    assert graph.calls == [
        ("resolve_default_drive", settings),
        (
            "download_file",
            "drive-id",
            "Folder/remote.txt",
            Path("downloads/local file.txt"),
            False,
        ),
    ]
    assert capsys.readouterr().out == "下载成功: downloads\\local file.txt\n"


@pytest.mark.parametrize(
    ("error", "expected_code"),
    [
        (ConfigError("配置无效"), 10),
        (AuthError("登录失败"), 20),
        (GraphError("Graph 失败"), 30),
        (LocalFileError("本地文件失败"), 40),
    ],
)
def test_main_maps_domain_errors_to_stable_exit_codes(
    monkeypatch, capsys, error, expected_code
):
    monkeypatch.setattr(cli, "run", lambda _args: (_ for _ in ()).throw(error))
    monkeypatch.setattr(cli.sys, "argv", ["main.py", "login"])

    assert cli.main() == expected_code

    captured = capsys.readouterr()
    assert captured.out == ""
    assert captured.err == f"错误: {error}\n"


def test_main_hides_unexpected_exception_details_and_traceback(monkeypatch, capsys):
    secret = "exception-secret-value"
    monkeypatch.setattr(
        cli,
        "run",
        lambda _args: (_ for _ in ()).throw(RuntimeError(secret)),
    )
    monkeypatch.setattr(cli.sys, "argv", ["main.py", "login"])

    assert cli.main() == 1

    captured = capsys.readouterr()
    assert captured.out == ""
    assert captured.err == "错误: 发生未预期错误；请使用文档中的排错步骤。\n"
    assert secret not in captured.err
    assert "Traceback" not in captured.err


def test_malformed_arguments_use_argparse_exit_code_2():
    with pytest.raises(SystemExit) as error:
        cli.build_parser().parse_args(["upload", "--source", "local.txt"])

    assert error.value.code == 2


def test_direct_main_does_not_reconfigure_injected_streams(monkeypatch):
    class RecordingStream(io.StringIO):
        def __init__(self):
            super().__init__()
            self.reconfigure_calls = []

        def reconfigure(self, **kwargs):
            self.reconfigure_calls.append(kwargs)

    stdout = RecordingStream()
    stderr = RecordingStream()
    monkeypatch.setattr(cli.sys, "stdout", stdout)
    monkeypatch.setattr(cli.sys, "stderr", stderr)
    monkeypatch.setattr(cli.sys, "argv", ["main.py", "--help"])

    with pytest.raises(SystemExit) as error:
        cli.main()

    assert error.value.code == 0
    assert stdout.reconfigure_calls == []
    assert stderr.reconfigure_calls == []


def test_configure_utf8_output_uses_strict_errors(monkeypatch):
    class RecordingStream:
        def __init__(self):
            self.reconfigure_calls = []

        def reconfigure(self, **kwargs):
            self.reconfigure_calls.append(kwargs)

    stdout = RecordingStream()
    stderr = RecordingStream()
    monkeypatch.setattr(cli.sys, "stdout", stdout)
    monkeypatch.setattr(cli.sys, "stderr", stderr)

    cli._configure_utf8_output()

    expected = [{"encoding": "utf-8", "errors": "strict"}]
    assert stdout.reconfigure_calls == expected
    assert stderr.reconfigure_calls == expected


def test_configure_utf8_output_propagates_reconfigure_failure(monkeypatch):
    class FailingStream:
        def reconfigure(self, **_kwargs):
            raise OSError("stream reconfigure failed")

    monkeypatch.setattr(cli.sys, "stdout", FailingStream())

    with pytest.raises(OSError, match="stream reconfigure failed"):
        cli._configure_utf8_output()


def test_piped_help_is_utf8_with_non_chinese_parent_encoding():
    environment = os.environ.copy()
    environment["PYTHONIOENCODING"] = "cp1252:strict"

    result = subprocess.run(
        [sys.executable, str(PROJECT_ROOT / "main.py"), "--help"],
        cwd=PROJECT_ROOT,
        env=environment,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )

    assert result.returncode == 0, result.stderr.decode("utf-8", errors="replace")
    output = result.stdout.decode("utf-8")
    assert "通过世纪互联" in output
    for command in ("login", "list", "upload", "download"):
        assert command in output
    assert result.stderr == b""


def test_help_exits_without_loading_configuration(monkeypatch, capsys):
    def forbidden_load():
        raise AssertionError("help must not load configuration")

    monkeypatch.setattr(cli, "load_settings", forbidden_load)
    monkeypatch.setattr(cli.sys, "argv", ["main.py", "--help"])

    with pytest.raises(SystemExit) as error:
        cli.main()

    assert error.value.code == 0
    output = capsys.readouterr().out
    for command in ("login", "list", "upload", "download"):
        assert command in output
