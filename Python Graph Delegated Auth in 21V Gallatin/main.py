import argparse
import sys
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import requests

from src.config import Settings, load_settings
from src.errors import DemoError, ExitCode
from src.graph_client import GraphClient
from src.oauth_pkce import authenticate


GraphClientFactory = Callable[[str, requests.Session], GraphClient]


def _create_graph_client(
    access_token: str, session: requests.Session
) -> GraphClient:
    return GraphClient(access_token, session=session)


@dataclass(frozen=True)
class Dependencies:
    load_settings: Callable[[], Settings] = load_settings
    session_factory: Callable[[], requests.Session] = requests.Session
    authenticate: Callable[[Settings, requests.Session], str] = authenticate
    graph_client_factory: GraphClientFactory = _create_graph_client


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="通过世纪互联 Microsoft Graph 操作 SharePoint 默认文档库"
    )
    commands = parser.add_subparsers(dest="command", required=True)

    commands.add_parser("login", help="交互登录并显示当前用户")

    list_parser = commands.add_parser("list", help="列出文件夹内容")
    list_parser.add_argument("--folder", default="", help="远程文件夹路径")

    upload_parser = commands.add_parser("upload", help="上传文件")
    upload_parser.add_argument("--source", required=True, type=Path, help="本地源文件")
    upload_parser.add_argument(
        "--destination", required=True, help="远程目标路径"
    )
    upload_parser.add_argument(
        "--overwrite", action="store_true", help="覆盖现有远程文件"
    )

    download_parser = commands.add_parser("download", help="下载文件")
    download_parser.add_argument("--source", required=True, help="远程源路径")
    download_parser.add_argument(
        "--destination", required=True, type=Path, help="本地目标路径"
    )
    download_parser.add_argument(
        "--overwrite", action="store_true", help="覆盖现有本地文件"
    )

    return parser


def run(
    args: argparse.Namespace, dependencies: Dependencies | None = None
) -> int:
    deps = dependencies or Dependencies()
    settings = deps.load_settings()
    session = deps.session_factory()
    try:
        access_token = deps.authenticate(settings, session)
        client = deps.graph_client_factory(access_token, session)

        if args.command == "login":
            user = client.get_current_user()
            print(f"显示名称: {_optional_value(user.get('displayName'))}")
            print(
                "用户主体名称: "
                f"{_optional_value(user.get('userPrincipalName'))}"
            )
            return int(ExitCode.OK)

        _site_id, drive_id = client.resolve_default_drive(settings)
        if args.command == "list":
            _print_items(client.list_children(drive_id, args.folder))
        elif args.command == "upload":
            client.upload_file(
                drive_id,
                args.source,
                args.destination,
                overwrite=args.overwrite,
            )
            print(f"上传成功: {args.destination}")
        elif args.command == "download":
            client.download_file(
                drive_id,
                args.source,
                args.destination,
                overwrite=args.overwrite,
            )
            print(f"下载成功: {args.destination}")
        return int(ExitCode.OK)
    finally:
        session.close()


def _print_items(items: list[dict[str, Any]]) -> None:
    print("类型\t名称\t大小\t修改时间\tWeb URL")
    for item in items:
        item_type = "DIR" if "folder" in item else "FILE"
        values = (
            item_type,
            _optional_value(item.get("name")),
            _optional_value(item.get("size")),
            _optional_value(item.get("lastModifiedDateTime")),
            _optional_value(item.get("webUrl")),
        )
        print("\t".join(str(value) for value in values))


def _optional_value(value: Any) -> Any:
    return "-" if value is None else value


def main() -> int:
    parser = build_parser()
    try:
        return run(parser.parse_args())
    except DemoError as error:
        print(f"错误: {error}", file=sys.stderr)
        return int(error.exit_code)
    except Exception:
        print(
            "错误: 发生未预期错误；请使用文档中的排错步骤。",
            file=sys.stderr,
        )
        return int(ExitCode.UNEXPECTED)


if __name__ == "__main__":
    raise SystemExit(main())
