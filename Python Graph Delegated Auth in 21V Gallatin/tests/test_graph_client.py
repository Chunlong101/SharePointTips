import json
import os
from pathlib import Path

import pytest
import requests

import src.graph_client as graph_client_module
from src.config import Settings, load_settings
from src.errors import GraphError, LocalFileError
from src.graph_client import (
    GRAPH_BASE_URL,
    HTTP_TIMEOUT,
    MAX_RETRIES,
    MAX_SIMPLE_UPLOAD_SIZE,
    GraphClient,
    encode_remote_path,
)


def test_encode_remote_path_encodes_each_segment_without_encoding_slashes():
    assert (
        encode_remote_path("中文 Folder/a#b.txt")
        == "%E4%B8%AD%E6%96%87%20Folder/a%23b.txt"
    )


@pytest.mark.parametrize(
    "path",
    ["/absolute", "a//b", ".", "..", "a/../b", ""],
)
def test_encode_remote_path_rejects_unsafe_or_empty_file_paths(path):
    with pytest.raises(GraphError, match="远程路径无效"):
        encode_remote_path(path)


def test_encode_remote_path_allows_empty_folder_path_only_when_requested():
    assert encode_remote_path("", allow_empty=True) == ""


def test_get_current_user_uses_gallatin_host_and_safe_transport_headers(
    fake_response, recording_session
):
    session = recording_session(
        fake_response(
            payload={
                "id": "user-id",
                "displayName": "Demo User",
                "userPrincipalName": "demo@contoso.cn",
            }
        )
    )
    client = GraphClient("token", session=session)

    user = client.get_current_user()

    assert user["id"] == "user-id"
    method, url, kwargs = session.calls[0]
    assert method == "GET"
    assert url == (
        "https://microsoftgraph.chinacloudapi.cn/v1.0/"
        "me?$select=id,displayName,userPrincipalName"
    )
    assert kwargs["headers"]["Authorization"] == "Bearer token"
    assert kwargs["headers"]["Accept"] == "application/json"
    assert kwargs["headers"]["client-request-id"]
    assert kwargs["timeout"] == HTTP_TIMEOUT
    assert "verify" not in kwargs or kwargs["verify"] is True


def test_graph_json_transport_does_not_follow_cross_host_redirects():
    class RedirectAdapter(requests.adapters.BaseAdapter):
        def __init__(self):
            self.requests = []

        def send(self, request, **kwargs):
            self.requests.append(request)
            response = requests.Response()
            response.request = request
            response.headers["Content-Type"] = "application/json"
            if len(self.requests) == 1:
                response.status_code = 302
                response.headers["Location"] = (
                    "https://graph.microsoft.com/v1.0/me?secret=redirect-target"
                )
                response._content = (
                    b'{"error":{"code":"unexpectedRedirect",'
                    b'"message":"secret redirect body"}}'
                )
            else:
                response.status_code = 200
                response._content = b'{"id":"global-user"}'
            return response

        def close(self):
            pass

    session = requests.Session()
    adapter = RedirectAdapter()
    session.mount("https://", adapter)

    with pytest.raises(GraphError) as exc_info:
        GraphClient("token", session=session).get_current_user()

    message = str(exc_info.value)
    assert len(adapter.requests) == 1
    assert "HTTP 302" in message
    assert "unexpected_redirect" in message
    assert "graph.microsoft.com" not in message
    assert "secret" not in message


def test_get_current_user_rejects_response_without_user_id(
    fake_response, recording_session
):
    session = recording_session(
        fake_response(
            payload={"displayName": "Missing ID"},
            headers={"request-id": "request-shape"},
        )
    )

    with pytest.raises(GraphError) as exc_info:
        GraphClient("token", session=session).get_current_user()

    assert "invalid_response" in str(exc_info.value)
    assert "request-shape" in str(exc_info.value)


def test_resolve_default_drive_preserves_graph_colon_and_encodes_unicode_site_path(
    fake_response, recording_session
):
    settings = Settings(
        tenant_id="11111111-1111-1111-1111-111111111111",
        client_id="22222222-2222-2222-2222-222222222222",
        sharepoint_site_url="https://contoso.sharepoint.cn/sites/中文 Demo",
        redirect_uri="http://localhost:8400/callback",
    )
    session = recording_session(
        fake_response(payload={"id": "site-id"}),
        fake_response(payload={"id": "drive-id"}),
    )

    result = GraphClient("token", session=session).resolve_default_drive(settings)

    assert result == ("site-id", "drive-id")
    assert session.calls[0][1] == (
        f"{GRAPH_BASE_URL}/sites/contoso.sharepoint.cn:"
        "/sites/%E4%B8%AD%E6%96%87%20Demo"
    )
    assert session.calls[1][1] == f"{GRAPH_BASE_URL}/sites/site-id/drive"


@pytest.mark.parametrize(
    ("site_path", "expected_graph_path"),
    [
        ("Demo%20Site", "Demo%20Site"),
        ("%E6%BC%94%E7%A4%BA%20Site", "%E6%BC%94%E7%A4%BA%20Site"),
    ],
)
def test_resolve_default_drive_encodes_normalized_site_path_once(
    tmp_path, site_path, expected_graph_path, fake_response, recording_session
):
    settings = load_settings(
        tmp_path / "missing.env",
        {
            "TENANT_ID": "11111111-1111-1111-1111-111111111111",
            "CLIENT_ID": "22222222-2222-2222-2222-222222222222",
            "SHAREPOINT_SITE_URL": (
                f"https://contoso.sharepoint.cn/sites/{site_path}"
            ),
            "REDIRECT_URI": "http://localhost:8400/callback",
        },
    )
    session = recording_session(
        fake_response(payload={"id": "site-id"}),
        fake_response(payload={"id": "drive-id"}),
    )

    GraphClient("token", session=session).resolve_default_drive(settings)

    assert session.calls[0][1] == (
        f"{GRAPH_BASE_URL}/sites/contoso.sharepoint.cn:/sites/{expected_graph_path}"
    )


def test_list_children_uses_distinct_root_and_encoded_folder_urls(
    fake_response, recording_session
):
    session = recording_session(
        fake_response(payload={"value": []}),
        fake_response(payload={"value": []}),
    )
    client = GraphClient("token", session=session)

    assert client.list_children("drive-id") == []
    assert client.list_children("drive-id", "中文 Folder") == []

    assert session.calls[0][1] == f"{GRAPH_BASE_URL}/drives/drive-id/root/children"
    assert session.calls[1][1] == (
        f"{GRAPH_BASE_URL}/drives/drive-id/root:"
        "/%E4%B8%AD%E6%96%87%20Folder:/children"
    )


def test_list_children_follows_all_trusted_gallatin_pagination_links(
    fake_response, recording_session
):
    next_link = f"{GRAPH_BASE_URL}/drives/drive-id/root/children?$skiptoken=next"
    session = recording_session(
        fake_response(payload={"value": [{"id": "one"}], "@odata.nextLink": next_link}),
        fake_response(payload={"value": [{"id": "two"}]}),
    )

    items = GraphClient("token", session=session).list_children("drive-id")

    assert [item["id"] for item in items] == ["one", "two"]
    assert session.calls[1][1] == next_link


@pytest.mark.parametrize(
    "next_link",
    [
        "http://microsoftgraph.chinacloudapi.cn/v1.0/next",
        "https://graph.microsoft.com/v1.0/next",
        "https://microsoftgraph.chinacloudapi.cn.evil.example/v1.0/next",
        "/v1.0/relative-next",
    ],
)
def test_list_children_rejects_untrusted_or_non_absolute_next_links(
    next_link, fake_response, recording_session
):
    session = recording_session(
        fake_response(payload={"value": [], "@odata.nextLink": next_link})
    )

    with pytest.raises(GraphError, match="分页链接"):
        GraphClient("token", session=session).list_children("drive-id")

    assert len(session.calls) == 1


def test_429_honors_numeric_retry_after_then_succeeds(fake_response, recording_session):
    sleeps = []
    session = recording_session(
        fake_response(
            status_code=429,
            payload={"error": {"code": "throttled", "message": "wait"}},
            headers={"Retry-After": "7"},
        ),
        fake_response(payload={"value": []}),
    )

    result = GraphClient("token", session=session, sleep=sleeps.append).list_children(
        "drive-id"
    )

    assert result == []
    assert sleeps == [7.0]
    assert len(session.calls) == 2


def test_retry_after_is_clamped_to_safe_maximum(fake_response, recording_session):
    sleeps = []
    session = recording_session(
        fake_response(status_code=429, payload={}, headers={"Retry-After": "999"}),
        fake_response(payload={"value": []}),
    )

    GraphClient("token", session=session, sleep=sleeps.append).list_children("drive-id")

    assert sleeps == [30.0]


@pytest.mark.parametrize("status", [429, 500, 502, 503, 504])
def test_retryable_http_failures_are_bounded(
    status, fake_response, recording_session
):
    responses = [
        fake_response(
            status_code=status,
            payload={"error": {"code": "temporary", "message": "do not leak"}},
        )
        for _ in range(MAX_RETRIES + 1)
    ]
    session = recording_session(*responses)

    with pytest.raises(GraphError, match=f"HTTP {status}"):
        GraphClient("token", session=session, sleep=lambda _delay: None).get_current_user()

    assert len(session.calls) == MAX_RETRIES + 1


def test_transport_failures_are_retried_but_bounded(recording_session):
    session = recording_session(
        *[requests.ConnectionError("token network detail") for _ in range(MAX_RETRIES + 1)]
    )

    with pytest.raises(GraphError) as exc_info:
        GraphClient("token", session=session, sleep=lambda _delay: None).get_current_user()

    assert len(session.calls) == MAX_RETRIES + 1
    assert "token" not in str(exc_info.value)
    assert "network detail" not in str(exc_info.value)


@pytest.mark.parametrize(
    ("status", "guidance"),
    [
        (401, "请重新登录，并确认应用和令牌属于 Gallatin 租户"),
        (403, "请确认委托权限已获同意，且当前用户有目标站点权限"),
        (404, "请检查站点 URL、默认文档库和远程路径是否正确"),
        (409, "请检查目标是否已存在，或使用 --overwrite 明确允许覆盖"),
    ],
)
def test_graph_http_errors_are_sanitized_and_include_diagnostics(
    status, guidance, fake_response, recording_session
):
    session = recording_session(
        fake_response(
            status_code=status,
            payload={
                "error": {
                    "code": "accessDenied",
                    "message": "token and secret-body must never leak",
                }
            },
            headers={"request-id": "request-123"},
        )
    )

    with pytest.raises(GraphError) as exc_info:
        GraphClient("token", session=session).get_current_user()

    message = str(exc_info.value)
    assert f"HTTP {status}" in message
    assert "accessDenied" in message
    assert "request-123" in message
    assert guidance in message
    assert "token" not in message
    assert "secret-body" not in message


def test_graph_diagnostic_uses_response_client_request_id_before_inner_fallback(
    fake_response, recording_session
):
    session = recording_session(
        fake_response(
            status_code=403,
            payload={
                "error": {
                    "code": "accessDenied",
                    "innerError": {"request-id": "inner-request-id"},
                }
            },
            headers={"client-request-id": "response-client-request-id"},
        )
    )

    with pytest.raises(GraphError) as caught:
        GraphClient("token", session=session).get_current_user()

    message = str(caught.value)
    assert "response-client-request-id" in message
    assert "inner-request-id" not in message


def test_malformed_json_response_raises_sanitized_graph_error(
    fake_response, recording_session
):
    session = recording_session(
        fake_response(
            status_code=200,
            headers={"request-id": "request-json"},
            json_error=json.JSONDecodeError("token body", "secret-body", 0),
        )
    )

    with pytest.raises(GraphError) as exc_info:
        GraphClient("token", session=session).get_current_user()

    message = str(exc_info.value)
    assert "HTTP 200" in message
    assert "invalid_response" in message
    assert "request-json" in message
    assert "token" not in message
    assert "secret-body" not in message


def test_success_response_missing_required_shape_is_rejected(
    fake_response, recording_session
):
    session = recording_session(fake_response(payload=[]))

    with pytest.raises(GraphError, match="invalid_response"):
        GraphClient("token", session=session).get_current_user()


def test_remote_item_exists_uses_encoded_metadata_url(fake_response, recording_session):
    session = recording_session(fake_response(payload={"id": "item-id"}))

    exists = GraphClient("token", session=session).remote_item_exists(
        "drive/id", "中文 Folder/a#b.txt"
    )

    assert exists is True
    assert session.calls[0][0:2] == (
        "GET",
        f"{GRAPH_BASE_URL}/drives/drive%2Fid/root:"
        "/%E4%B8%AD%E6%96%87%20Folder/a%23b.txt",
    )


def test_remote_item_exists_returns_false_for_parsed_graph_404(
    fake_response, recording_session
):
    session = recording_session(
        fake_response(
            status_code=404,
            payload={"error": {"code": "itemNotFound", "message": "not found"}},
        )
    )

    assert GraphClient("token", session=session).remote_item_exists(
        "drive-id", "missing.txt"
    ) is False


@pytest.mark.parametrize(
    "response",
    [
        pytest.param(
            {"status_code": 403, "payload": {"error": {"code": "accessDenied"}}},
            id="non-404",
        ),
        pytest.param(
            {"status_code": 404, "json_error": ValueError("malformed secret")},
            id="unparsed-404",
        ),
    ],
)
def test_remote_item_exists_propagates_every_error_except_parsed_404(
    response, fake_response, recording_session
):
    session = recording_session(fake_response(**response))

    with pytest.raises(GraphError):
        GraphClient("token", session=session).remote_item_exists(
            "drive-id", "missing.txt"
        )


@pytest.mark.parametrize("source_kind", ["missing", "directory"])
def test_upload_rejects_missing_or_non_file_source_before_network(
    source_kind, tmp_path, recording_session
):
    source = tmp_path / source_kind
    if source_kind == "directory":
        source.mkdir()
    session = recording_session()

    with pytest.raises(LocalFileError, match="上传源文件"):
        GraphClient("token", session=session).upload_file(
            "drive-id", source, "target.bin"
        )

    assert session.calls == []


def test_upload_rejects_source_larger_than_250_mib_before_network(
    tmp_path, recording_session
):
    source = tmp_path / "oversized.bin"
    with source.open("wb") as handle:
        handle.seek(250 * 1024 * 1024)
        handle.write(b"x")
    session = recording_session()

    with pytest.raises(LocalFileError, match="250"):
        GraphClient("token", session=session).upload_file(
            "drive-id", source, "target.bin"
        )

    assert session.calls == []


def test_upload_accepts_source_exactly_250_mib(tmp_path, fake_response, recording_session):
    source = tmp_path / "maximum.bin"
    with source.open("wb") as handle:
        handle.truncate(MAX_SIMPLE_UPLOAD_SIZE)
    session = recording_session(fake_response(payload={"id": "uploaded"}))

    item = GraphClient("token", session=session).upload_file(
        "drive-id", source, "target.bin", overwrite=True
    )

    assert item == {"id": "uploaded"}
    assert [call[0] for call in session.calls] == ["PUT"]


def test_upload_validates_size_from_open_file_descriptor_before_put(
    tmp_path, fake_response, recording_session, monkeypatch
):
    source = tmp_path / "source.bin"
    source.write_bytes(b"content")
    session = recording_session(fake_response(payload={"id": "uploaded"}))
    real_fstat = os.fstat
    events = []

    def recording_fstat(file_descriptor):
        events.append(("fstat", file_descriptor))
        return real_fstat(file_descriptor)

    original_request = session.request

    def recording_request(method, url, **kwargs):
        data = kwargs.get("data")
        events.append((method, data.fileno() if data is not None else None))
        return original_request(method, url, **kwargs)

    monkeypatch.setattr(graph_client_module.os, "fstat", recording_fstat)
    session.request = recording_request

    GraphClient("token", session=session).upload_file(
        "drive-id", source, "target.bin", overwrite=True
    )

    assert [event[0] for event in events][-2:] == ["fstat", "PUT"]
    assert events[-2][1] == events[-1][1]


@pytest.mark.parametrize("destination", ["", "/absolute", "folder/../target.bin"])
def test_upload_rejects_invalid_destination_before_network(
    destination, tmp_path, recording_session
):
    source = tmp_path / "source.bin"
    source.write_bytes(b"content")
    session = recording_session()

    with pytest.raises(GraphError, match="远程路径无效"):
        GraphClient("token", session=session).upload_file(
            "drive-id", source, destination
        )

    assert session.calls == []


def test_upload_refuses_existing_remote_target_without_overwrite(
    tmp_path, fake_response, recording_session
):
    source = tmp_path / "source.bin"
    source.write_bytes(b"content")
    session = recording_session(fake_response(payload={"id": "existing"}))

    with pytest.raises(GraphError, match="已存在"):
        GraphClient("token", session=session).upload_file(
            "drive-id", source, "target.bin"
        )

    assert [call[0] for call in session.calls] == ["GET"]


def test_upload_puts_file_stream_once_with_binary_content_type(
    tmp_path, fake_response, recording_session
):
    source = tmp_path / "source.bin"
    source.write_bytes(b"stream me")
    session = recording_session(
        fake_response(
            status_code=404,
            payload={"error": {"code": "itemNotFound"}},
        ),
        fake_response(payload={"id": "uploaded"}),
    )

    item = GraphClient("token", session=session).upload_file(
        "drive/id", source, "中文 Folder/a#b.bin"
    )

    assert item == {"id": "uploaded"}
    method, url, kwargs = session.calls[1]
    assert method == "PUT"
    assert url == (
        f"{GRAPH_BASE_URL}/drives/drive%2Fid/root:"
        "/%E4%B8%AD%E6%96%87%20Folder/a%23b.bin:/content"
    )
    assert kwargs["headers"]["Content-Type"] == "application/octet-stream"
    assert kwargs["headers"]["If-None-Match"] == "*"
    assert hasattr(kwargs["data"], "read")
    assert not isinstance(kwargs["data"], (bytes, bytearray))
    assert kwargs["data"].closed


def test_upload_with_overwrite_skips_preflight_and_conditional_header(
    tmp_path, fake_response, recording_session
):
    source = tmp_path / "source.bin"
    source.write_bytes(b"replacement")
    session = recording_session(fake_response(payload={"id": "uploaded"}))

    GraphClient("token", session=session).upload_file(
        "drive-id", source, "target.bin", overwrite=True
    )

    assert [call[0] for call in session.calls] == ["PUT"]
    assert "If-None-Match" not in session.calls[0][2]["headers"]


@pytest.mark.parametrize("status", [409, 412])
def test_upload_maps_conditional_put_race_to_existing_target_error(
    status, tmp_path, fake_response, recording_session
):
    source = tmp_path / "source.bin"
    source.write_bytes(b"content")
    session = recording_session(
        fake_response(
            status_code=404,
            payload={"error": {"code": "itemNotFound"}},
        ),
        fake_response(
            status_code=status,
            payload={"error": {"code": "nameAlreadyExists"}},
        ),
    )

    with pytest.raises(GraphError, match="已存在"):
        GraphClient("token", session=session).upload_file(
            "drive-id", source, "target.bin"
        )

    assert [call[0] for call in session.calls] == ["GET", "PUT"]
    assert session.calls[1][2]["headers"]["If-None-Match"] == "*"


def test_upload_does_not_retry_put_after_transport_failure(
    tmp_path, fake_response, recording_session
):
    source = tmp_path / "source.bin"
    source.write_bytes(b"content")
    session = recording_session(
        fake_response(
            status_code=404,
            payload={"error": {"code": "itemNotFound"}},
        ),
        requests.ConnectionError("secret transport detail"),
    )

    with pytest.raises(GraphError) as exc_info:
        GraphClient("token", session=session).upload_file(
            "drive-id", source, "target.bin"
        )

    assert [call[0] for call in session.calls] == ["GET", "PUT"]
    assert "secret transport detail" not in str(exc_info.value)


class StreamingResponse:
    def __init__(self, chunks, status_code=200, headers=None, close_error=None):
        self.status_code = status_code
        self.headers = headers or {}
        self._chunks = chunks
        self.close_calls = 0
        self._close_error = close_error

    def iter_content(self, chunk_size):
        assert chunk_size == 64 * 1024
        yield from self._chunks

    def json(self):
        return {"error": {"code": "downloadFailed", "message": "secret body"}}

    def close(self):
        self.close_calls += 1
        if self._close_error is not None:
            raise self._close_error


def test_download_initial_get_retries_safely_before_body_consumption(
    tmp_path, fake_response, recording_session
):
    throttled = fake_response(
        status_code=429,
        payload={"error": {"code": "throttled"}},
        headers={"Retry-After": "999"},
    )
    unavailable = fake_response(
        status_code=503,
        payload={"error": {"code": "unavailable"}},
    )
    success = StreamingResponse([b"downloaded"])
    session = recording_session(
        requests.ConnectionError("transport secret"),
        throttled,
        unavailable,
        success,
    )
    sleeps = []

    destination = GraphClient(
        "token", session=session, sleep=sleeps.append
    ).download_file("drive-id", "remote.bin", tmp_path / "download.bin")

    assert destination.read_bytes() == b"downloaded"
    assert len(session.calls) == MAX_RETRIES + 1
    assert sleeps == [1.0, 30.0, 4.0]
    assert throttled.close_calls == 1
    assert unavailable.close_calls == 1
    assert success.close_calls == 1


def test_download_redirect_get_retries_without_credentials_or_refollowing_redirects(
    tmp_path, fake_response, recording_session
):
    download_url = "https://download.example.cn/preauthenticated"
    initial = fake_response(status_code=302, headers={"Location": download_url})
    graph_session = recording_session(initial)
    unavailable = fake_response(
        status_code=502,
        payload={"error": {"code": "unavailable"}},
    )
    redirected = StreamingResponse([b"redirected"])
    redirect_session = recording_session(
        requests.ConnectionError("redirect transport secret"),
        unavailable,
        redirected,
    )
    redirect_session.auth = ("user", "password")
    redirect_session.cert = "secret-cert"
    redirect_session.trust_env = True
    redirect_session.headers = {"Authorization": "Bearer inherited"}
    redirect_session.cookies = {}
    redirect_session.params = {}
    redirect_session.proxies = {}
    sleeps = []

    GraphClient(
        "token",
        session=graph_session,
        sleep=sleeps.append,
        download_session_factory=lambda: redirect_session,
    ).download_file("drive-id", "remote.bin", tmp_path / "download.bin")

    assert sleeps == [1.0, 2.0]
    assert len(graph_session.calls) == 1
    assert len(redirect_session.calls) == 3
    assert initial.close_calls == 1
    assert unavailable.close_calls == 1
    for _method, _url, kwargs in redirect_session.calls:
        assert "Authorization" not in kwargs["headers"]


def test_download_follows_at_most_one_redirect(
    tmp_path, fake_response, recording_session
):
    initial = fake_response(
        status_code=302,
        headers={"Location": "https://download.example.cn/first"},
    )
    second_redirect = fake_response(
        status_code=307,
        headers={"Location": "https://other.example.cn/second-secret"},
    )
    graph_session = recording_session(initial)
    redirect_session = recording_session(second_redirect)
    redirect_session.auth = None
    redirect_session.cert = None
    redirect_session.trust_env = False
    redirect_session.headers = {}
    redirect_session.cookies = {}
    redirect_session.params = {}
    redirect_session.proxies = {}

    with pytest.raises(GraphError) as caught:
        GraphClient(
            "token",
            session=graph_session,
            download_session_factory=lambda: redirect_session,
        ).download_file("drive-id", "remote.bin", tmp_path / "download.bin")

    assert len(graph_session.calls) == 1
    assert len(redirect_session.calls) == 1
    assert initial.close_calls == 1
    assert second_redirect.close_calls == 1
    assert "second-secret" not in str(caught.value)


def test_download_does_not_retry_after_stream_consumption_begins(
    tmp_path, recording_session
):
    def interrupted_chunks():
        yield b"partial"
        raise requests.ConnectionError("stream secret")

    session = recording_session(StreamingResponse(interrupted_chunks()))
    sleeps = []

    with pytest.raises(GraphError, match="下载流中断"):
        GraphClient("token", session=session, sleep=sleeps.append).download_file(
            "drive-id", "remote.bin", tmp_path / "download.bin"
        )

    assert len(session.calls) == 1
    assert sleeps == []


def test_download_rejects_existing_target_without_overwrite_before_network(
    tmp_path, recording_session
):
    destination = tmp_path / "existing.bin"
    destination.write_bytes(b"original")
    session = recording_session()

    with pytest.raises(LocalFileError, match="已存在"):
        GraphClient("token", session=session).download_file(
            "drive-id", "remote.bin", destination
        )

    assert destination.read_bytes() == b"original"
    assert session.calls == []


def test_download_streams_to_same_directory_then_atomically_links_without_overwrite(
    tmp_path, monkeypatch, recording_session
):
    destination = tmp_path / "new" / "folder" / "download.bin"
    response = StreamingResponse([b"first", b"", b"-second"])
    session = recording_session(response)
    real_link = os.link
    links = []

    def recording_link(source, target):
        source = Path(source)
        target = Path(target)
        assert source.parent == destination.parent
        assert source.read_bytes() == b"first-second"
        assert not destination.exists()
        links.append((source, target))
        real_link(source, target)

    monkeypatch.setattr(os, "link", recording_link)

    result = GraphClient("token", session=session).download_file(
        "drive/id", "中文 Folder/a#b.bin", destination
    )

    assert result == destination
    assert destination.read_bytes() == b"first-second"
    assert len(links) == 1
    assert response.close_calls == 1
    method, url, kwargs = session.calls[0]
    assert method == "GET"
    assert url == (
        f"{GRAPH_BASE_URL}/drives/drive%2Fid/root:"
        "/%E4%B8%AD%E6%96%87%20Folder/a%23b.bin:/content"
    )
    assert kwargs["stream"] is True


def test_download_with_overwrite_atomically_replaces_existing_target(
    tmp_path, monkeypatch, recording_session
):
    destination = tmp_path / "download.bin"
    destination.write_bytes(b"original")
    session = recording_session(StreamingResponse([b"replacement"]))
    real_replace = os.replace
    replacements = []

    def recording_replace(source, target):
        replacements.append((Path(source), Path(target)))
        real_replace(source, target)

    monkeypatch.setattr(os, "replace", recording_replace)

    GraphClient("token", session=session).download_file(
        "drive-id", "remote.bin", destination, overwrite=True
    )

    assert destination.read_bytes() == b"replacement"
    assert len(replacements) == 1


def test_download_no_overwrite_preserves_destination_created_during_commit(
    tmp_path, monkeypatch, recording_session
):
    destination = tmp_path / "download.bin"
    session = recording_session(StreamingResponse([b"downloaded"]))

    def racing_link(_source, target):
        Path(target).write_bytes(b"concurrent winner")
        raise FileExistsError("adapter detail")

    monkeypatch.setattr(os, "link", racing_link)

    with pytest.raises(LocalFileError, match="已存在") as exc_info:
        GraphClient("token", session=session).download_file(
            "drive-id", "remote.bin", destination
        )

    assert destination.read_bytes() == b"concurrent winner"
    assert list(tmp_path.iterdir()) == [destination]
    assert "adapter detail" not in str(exc_info.value)


def test_download_redirect_uses_credential_free_session_and_effective_request(
    tmp_path,
):
    download_url = "https://download.example.cn/preauthenticated?secret=opaque"
    destination = tmp_path / "download.bin"

    class TrackingResponse(requests.Response):
        def __init__(self):
            super().__init__()
            self.close_calls = 0

        def close(self):
            self.close_calls += 1
            super().close()

    first_response = TrackingResponse()
    first_response.status_code = 302
    first_response.headers["Location"] = download_url
    first_response._content = b""

    class Adapter(requests.adapters.BaseAdapter):
        def __init__(self, response, require_first_closed=False):
            self.response = response
            self.require_first_closed = require_first_closed
            self.requests = []
            self.send_kwargs = []

        def send(self, request, **kwargs):
            if self.require_first_closed:
                assert first_response.close_calls >= 1
            self.requests.append(request)
            self.send_kwargs.append(kwargs)
            self.response.request = request
            return self.response

        def close(self):
            pass

    graph_session = requests.Session()
    graph_session.auth = ("session-user", "session-password")
    graph_session.headers.update(
        {"Authorization": "Bearer session-default", "X-Api-Key": "secret-key"}
    )
    graph_session.cookies.set("session-cookie", "secret-cookie")
    graph_adapter = Adapter(first_response)
    graph_session.mount("https://", graph_adapter)

    redirected_response = requests.Response()
    redirected_response.status_code = 200
    redirected_response._content = b"redirected content"
    redirected_response._content_consumed = True
    redirect_session = requests.Session()
    redirect_session.auth = ("redirect-user", "redirect-password")
    redirect_session.headers.update(
        {"Authorization": "Bearer redirect-default", "X-Api-Key": "redirect-key"}
    )
    redirect_session.cookies.set("redirect-cookie", "redirect-secret")
    redirect_session.params["credential"] = "redirect-query-secret"
    redirect_adapter = Adapter(redirected_response, require_first_closed=True)
    redirect_session.mount("https://", redirect_adapter)

    GraphClient(
        "graph-token",
        session=graph_session,
        download_session_factory=lambda: redirect_session,
    ).download_file("drive-id", "remote.bin", destination)

    assert destination.read_bytes() == b"redirected content"
    assert len(graph_adapter.requests) == 1
    assert len(redirect_adapter.requests) == 1
    redirected_request = redirect_adapter.requests[0]
    assert redirected_request.url == download_url
    assert "Authorization" not in redirected_request.headers
    assert "Cookie" not in redirected_request.headers
    assert "X-Api-Key" not in redirected_request.headers
    assert redirect_adapter.send_kwargs[0]["verify"] is True
    assert redirect_adapter.send_kwargs[0]["timeout"] == HTTP_TIMEOUT
    assert redirect_adapter.send_kwargs[0]["stream"] is True
    assert first_response.close_calls >= 1


def test_download_rejects_non_https_redirect_before_second_request(
    tmp_path, fake_response, recording_session
):
    session = recording_session(
        fake_response(
            status_code=302,
            headers={"Location": "http://download.example.cn/unsafe"},
        )
    )

    with pytest.raises(GraphError, match="重定向"):
        GraphClient("token", session=session).download_file(
            "drive-id", "remote.bin", tmp_path / "download.bin"
        )

    assert len(session.calls) == 1


def test_download_removes_temporary_file_after_interrupted_stream(
    tmp_path, recording_session
):
    destination = tmp_path / "nested" / "download.bin"

    def interrupted_chunks():
        yield b"partial"
        raise requests.ConnectionError("token and secret transport detail")

    session = recording_session(StreamingResponse(interrupted_chunks()))

    with pytest.raises(GraphError) as exc_info:
        GraphClient("token", session=session).download_file(
            "drive-id", "remote.bin", destination
        )

    assert not destination.exists()
    assert list(destination.parent.iterdir()) == []
    assert "token" not in str(exc_info.value)
    assert "secret" not in str(exc_info.value)


def test_download_close_failure_does_not_mask_stream_error_or_prevent_cleanup(
    tmp_path, recording_session
):
    destination = tmp_path / "nested" / "download.bin"

    def interrupted_chunks():
        yield b"partial"
        raise requests.ConnectionError("primary transport detail")

    response = StreamingResponse(
        interrupted_chunks(), close_error=RuntimeError("adapter close secret")
    )
    session = recording_session(response)

    with pytest.raises(GraphError, match="下载流中断") as exc_info:
        GraphClient("token", session=session).download_file(
            "drive-id", "remote.bin", destination
        )

    assert response.close_calls == 1
    assert not destination.exists()
    assert list(destination.parent.iterdir()) == []
    assert "primary transport detail" not in str(exc_info.value)
    assert "adapter close secret" not in str(exc_info.value)