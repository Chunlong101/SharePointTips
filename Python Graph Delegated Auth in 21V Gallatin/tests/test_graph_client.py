import json

import pytest
import requests

from src.config import Settings
from src.errors import GraphError
from src.graph_client import (
    GRAPH_BASE_URL,
    HTTP_TIMEOUT,
    MAX_RETRIES,
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
    with pytest.raises(GraphError, match="remote path"):
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

    with pytest.raises(GraphError, match="pagination"):
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

    with pytest.raises(GraphError, match=f"status {status}"):
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


@pytest.mark.parametrize("status", [401, 403, 404])
def test_graph_http_errors_are_sanitized_and_include_diagnostics(
    status, fake_response, recording_session
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
    assert f"status {status}" in message
    assert "accessDenied" in message
    assert "request-123" in message
    assert "token" not in message
    assert "secret-body" not in message


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
    assert "status 200" in message
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