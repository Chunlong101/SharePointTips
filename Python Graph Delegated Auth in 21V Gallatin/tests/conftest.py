from collections import deque

import pytest
import requests

from src.config import Settings


class FakeResponse:
    def __init__(self, status_code=200, payload=None, headers=None, json_error=None):
        self.status_code = status_code
        self._payload = payload
        self.headers = headers or {}
        self._json_error = json_error

    def json(self):
        if self._json_error is not None:
            raise self._json_error
        return self._payload


class RecordingSession:
    def __init__(self, *results):
        self.results = deque(results)
        self.calls = []

    def request(self, method, url, **kwargs):
        self.calls.append((method, url, kwargs))
        if not self.results:
            raise AssertionError("Unexpected HTTP request")
        result = self.results.popleft()
        if isinstance(result, requests.RequestException):
            raise result
        return result


@pytest.fixture
def settings():
    return Settings(
        tenant_id="11111111-1111-1111-1111-111111111111",
        client_id="22222222-2222-2222-2222-222222222222",
        sharepoint_site_url="https://contoso.sharepoint.cn/sites/Demo",
        redirect_uri="http://localhost:8400/callback",
    )


@pytest.fixture
def fake_response():
    return FakeResponse


@pytest.fixture
def recording_session():
    return RecordingSession