import time
from collections.abc import Callable
from typing import Any
from urllib.parse import quote, urlsplit
from uuid import uuid4

import requests

from .config import Settings
from .errors import GraphError


GRAPH_BASE_URL = "https://microsoftgraph.chinacloudapi.cn/v1.0"
GRAPH_HOST = "microsoftgraph.chinacloudapi.cn"
HTTP_TIMEOUT = (10, 60)
MAX_RETRIES = 3
MAX_RETRY_AFTER = 30

_RETRYABLE_STATUS_CODES = {429, 500, 502, 503, 504}


def encode_remote_path(path: str, allow_empty: bool = False) -> str:
    if path == "" and allow_empty:
        return ""
    if not isinstance(path, str) or not path or path.startswith("/"):
        raise GraphError("Invalid remote path")

    segments = path.split("/")
    if any(segment in {"", ".", ".."} for segment in segments):
        raise GraphError("Invalid remote path")
    return "/".join(quote(segment, safe="") for segment in segments)


class GraphClient:
    def __init__(
        self,
        access_token: str,
        session: requests.Session | None = None,
        sleep: Callable[[float], None] = time.sleep,
    ) -> None:
        self._access_token = access_token
        self._session = session if session is not None else requests.Session()
        self._sleep = sleep

    def _request(self, method: str, url: str) -> tuple[Any, requests.Response]:
        self._require_trusted_graph_url(url, "request URL")

        for retry_number in range(MAX_RETRIES + 1):
            headers = {
                "Authorization": f"Bearer {self._access_token}",
                "Accept": "application/json",
                "client-request-id": str(uuid4()),
            }
            try:
                response = self._session.request(
                    method,
                    url,
                    headers=headers,
                    timeout=HTTP_TIMEOUT,
                    verify=True,
                    allow_redirects=False,
                )
            except requests.RequestException:
                if retry_number < MAX_RETRIES:
                    self._sleep(self._backoff_delay(retry_number))
                    continue
                raise GraphError("Graph request failed after bounded retries") from None

            if (
                response.status_code in _RETRYABLE_STATUS_CODES
                and retry_number < MAX_RETRIES
            ):
                self._sleep(self._retry_delay(response, retry_number))
                continue

            if 300 <= response.status_code < 400:
                raise self._response_error(
                    response, code="unexpected_redirect"
                )

            try:
                payload = response.json()
            except (ValueError, TypeError):
                raise self._response_error(
                    response, code="invalid_response"
                ) from None

            if not 200 <= response.status_code < 300:
                raise self._response_error(response, payload=payload)
            return payload, response

        raise GraphError("Graph request failed after bounded retries")

    def get_current_user(self) -> dict[str, Any]:
        payload, response = self._request(
            "GET",
            f"{GRAPH_BASE_URL}/me?$select=id,displayName,userPrincipalName",
        )
        if not isinstance(payload, dict):
            raise self._response_error(response, code="invalid_response")
        self._required_id(payload, response)
        return payload

    def resolve_default_drive(self, settings: Settings) -> tuple[str, str]:
        site_path = settings.site_path.removeprefix("/")
        encoded_site_path = encode_remote_path(site_path, allow_empty=True)
        site_url = f"{GRAPH_BASE_URL}/sites/{settings.site_hostname}:/{encoded_site_path}"
        site, site_response = self._request("GET", site_url)
        site_id = self._required_id(site, site_response)

        drive, drive_response = self._request(
            "GET", f"{GRAPH_BASE_URL}/sites/{quote(site_id, safe='')}/drive"
        )
        return site_id, self._required_id(drive, drive_response)

    def list_children(
        self, drive_id: str, folder: str = ""
    ) -> list[dict[str, Any]]:
        encoded_drive_id = quote(drive_id, safe="")
        if folder:
            encoded_folder = encode_remote_path(folder)
            next_url = (
                f"{GRAPH_BASE_URL}/drives/{encoded_drive_id}/root:"
                f"/{encoded_folder}:/children"
            )
        else:
            next_url = f"{GRAPH_BASE_URL}/drives/{encoded_drive_id}/root/children"

        items: list[dict[str, Any]] = []
        while next_url:
            page, response = self._request("GET", next_url)
            if not isinstance(page, dict) or not isinstance(page.get("value"), list):
                raise self._response_error(response, code="invalid_response")
            if not all(isinstance(item, dict) for item in page["value"]):
                raise self._response_error(response, code="invalid_response")
            items.extend(page["value"])

            candidate = page.get("@odata.nextLink")
            if candidate is None:
                next_url = ""
            elif not isinstance(candidate, str):
                raise GraphError("Invalid Graph pagination link")
            else:
                self._require_trusted_graph_url(candidate, "pagination link")
                next_url = candidate
        return items

    def _required_id(self, payload: Any, response: requests.Response) -> str:
        if not isinstance(payload, dict):
            raise self._response_error(response, code="invalid_response")
        value = payload.get("id")
        if not isinstance(value, str) or not value:
            raise self._response_error(response, code="invalid_response")
        return value

    @staticmethod
    def _require_trusted_graph_url(url: str, label: str) -> None:
        try:
            parsed = urlsplit(url)
            port = parsed.port
        except (TypeError, ValueError) as exc:
            raise GraphError(f"Invalid Graph {label}") from exc
        trusted = (
            parsed.scheme == "https"
            and parsed.hostname == GRAPH_HOST
            and parsed.netloc == GRAPH_HOST
            and port is None
            and parsed.username is None
            and parsed.password is None
        )
        if not trusted:
            raise GraphError(f"Invalid Graph {label}")

    @staticmethod
    def _backoff_delay(retry_number: int) -> float:
        return float(min(2**retry_number, MAX_RETRY_AFTER))

    def _retry_delay(self, response: Any, retry_number: int) -> float:
        if response.status_code == 429:
            retry_after = response.headers.get("Retry-After")
            try:
                delay = float(retry_after)
            except (TypeError, ValueError):
                pass
            else:
                return min(max(delay, 0.0), float(MAX_RETRY_AFTER))
        return self._backoff_delay(retry_number)

    def _response_error(
        self,
        response: Any,
        payload: Any = None,
        code: str | None = None,
    ) -> GraphError:
        graph_code = code or "unknown_error"
        request_id = response.headers.get("request-id") or "unknown"
        if isinstance(payload, dict):
            error = payload.get("error")
            if isinstance(error, dict):
                candidate_code = error.get("code")
                if isinstance(candidate_code, str) and candidate_code:
                    graph_code = candidate_code
                inner_error = error.get("innerError") or error.get("innererror")
                if isinstance(inner_error, dict):
                    candidate_request_id = (
                        inner_error.get("request-id")
                        or inner_error.get("requestId")
                    )
                    if isinstance(candidate_request_id, str) and candidate_request_id:
                        request_id = candidate_request_id

        safe_code = self._safe_metadata(graph_code, "unknown_error")
        safe_request_id = self._safe_metadata(request_id, "unknown")
        message = (
            f"Graph response status {response.status_code} "
            f"code {safe_code} request-id {safe_request_id}"
        )
        if self._access_token:
            message = message.replace(self._access_token, "[redacted]")
        return GraphError(message)

    @staticmethod
    def _safe_metadata(value: str, fallback: str) -> str:
        if len(value) > 128 or any(
            not (character.isalnum() or character in "._-")
            for character in value
        ):
            return fallback
        return value