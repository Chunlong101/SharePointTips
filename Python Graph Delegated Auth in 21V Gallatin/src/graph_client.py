import os
import stat
import tempfile
import time
from collections.abc import Callable
from pathlib import Path
from typing import Any
from urllib.parse import quote, urlsplit
from uuid import uuid4

import requests

from .config import Settings
from .errors import GraphError, LocalFileError


GRAPH_BASE_URL = "https://microsoftgraph.chinacloudapi.cn/v1.0"
GRAPH_HOST = "microsoftgraph.chinacloudapi.cn"
HTTP_TIMEOUT = (10, 60)
MAX_RETRIES = 3
MAX_RETRY_AFTER = 30
MAX_SIMPLE_UPLOAD_SIZE = 250 * 1024 * 1024

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
        download_session_factory: Callable[[], requests.Session] = requests.Session,
    ) -> None:
        self._access_token = access_token
        self._session = session if session is not None else requests.Session()
        self._sleep = sleep
        self._download_session_factory = download_session_factory

    def _request(
        self,
        method: str,
        url: str,
        *,
        headers: dict[str, str] | None = None,
        data: Any = None,
        retry: bool = True,
        accepted_statuses: set[int] | None = None,
    ) -> tuple[Any, requests.Response]:
        self._require_trusted_graph_url(url, "request URL")

        maximum_retries = MAX_RETRIES if retry else 0
        for retry_number in range(maximum_retries + 1):
            request_headers = {
                "Authorization": f"Bearer {self._access_token}",
                "Accept": "application/json",
                "client-request-id": str(uuid4()),
            }
            if headers:
                request_headers.update(headers)
            try:
                response = self._session.request(
                    method,
                    url,
                    headers=request_headers,
                    data=data,
                    timeout=HTTP_TIMEOUT,
                    verify=True,
                    allow_redirects=False,
                )
            except requests.RequestException:
                if retry_number < maximum_retries:
                    self._sleep(self._backoff_delay(retry_number))
                    continue
                raise GraphError("Graph request failed after bounded retries") from None

            if (
                response.status_code in _RETRYABLE_STATUS_CODES
                and retry_number < maximum_retries
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

            status_accepted = (
                accepted_statuses is not None
                and response.status_code in accepted_statuses
            )
            if not 200 <= response.status_code < 300 and not status_accepted:
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

    def remote_item_exists(self, drive_id: str, remote_path: str) -> bool:
        url = self._item_url(drive_id, remote_path)
        _payload, response = self._request(
            "GET", url, accepted_statuses={404}
        )
        return response.status_code != 404

    def upload_file(
        self,
        drive_id: str,
        source: Path,
        destination: str,
        overwrite: bool = False,
    ) -> dict[str, Any]:
        encoded_destination = encode_remote_path(destination)
        source = Path(source)
        try:
            with source.open("rb") as stream:
                self._validate_upload_stream(stream)
        except LocalFileError:
            raise
        except OSError:
            raise LocalFileError("Unable to inspect upload source") from None

        if not overwrite and self.remote_item_exists(drive_id, destination):
            raise GraphError("Remote destination already exists")

        url = self._item_url(drive_id, encoded_destination, encoded=True) + ":/content"
        headers = {"Content-Type": "application/octet-stream"}
        accepted_statuses = None
        if not overwrite:
            headers["If-None-Match"] = "*"
            accepted_statuses = {409, 412}
        try:
            with source.open("rb") as stream:
                self._validate_upload_stream(stream)
                payload, response = self._request(
                    "PUT",
                    url,
                    headers=headers,
                    data=stream,
                    retry=False,
                    accepted_statuses=accepted_statuses,
                )
                if response.status_code in {409, 412}:
                    raise GraphError("Remote destination already exists")
        except LocalFileError:
            raise
        except OSError:
            raise LocalFileError("Unable to read upload source") from None
        if not isinstance(payload, dict):
            raise self._response_error(response, code="invalid_response")
        return payload

    def download_file(
        self,
        drive_id: str,
        source: str,
        destination: Path,
        overwrite: bool = False,
    ) -> Path:
        source_url = self._item_url(drive_id, source) + ":/content"
        destination = Path(destination)
        if destination.exists() and not overwrite:
            raise LocalFileError("Download destination already exists")

        try:
            destination.parent.mkdir(parents=True, exist_ok=True)
        except OSError:
            raise LocalFileError("Unable to create download destination") from None

        temp_name: str | None = None
        response: Any = None
        redirect_session: requests.Session | None = None
        try:
            response = self._download_request(
                self._session, source_url, include_authorization=True
            )
            if 300 <= response.status_code < 400:
                location = response.headers.get("Location")
                self._require_safe_download_redirect(location)
                self._close_response(response)
                response = None
                redirect_session = self._download_session_factory()
                self._remove_session_credentials(redirect_session)
                response = self._download_request(
                    redirect_session, location, include_authorization=False
                )

            if 300 <= response.status_code < 400:
                raise self._response_error(response, code="unexpected_redirect")
            if not 200 <= response.status_code < 300:
                try:
                    payload = response.json()
                except (ValueError, TypeError):
                    raise self._response_error(
                        response, code="invalid_response"
                    ) from None
                raise self._response_error(response, payload=payload)

            with tempfile.NamedTemporaryFile(
                mode="wb", delete=False, dir=destination.parent
            ) as temp_file:
                temp_name = temp_file.name
                try:
                    for chunk in response.iter_content(64 * 1024):
                        if chunk:
                            temp_file.write(chunk)
                except requests.RequestException:
                    raise GraphError("Graph download stream failed") from None
                temp_file.flush()
            if overwrite:
                os.replace(temp_name, destination)
            else:
                try:
                    os.link(temp_name, destination)
                except FileExistsError:
                    raise LocalFileError(
                        "Download destination already exists"
                    ) from None
                os.unlink(temp_name)
            temp_name = None
            return destination
        except (GraphError, LocalFileError):
            raise
        except requests.RequestException:
            raise GraphError("Graph download request failed") from None
        except OSError:
            raise LocalFileError("Local download operation failed") from None
        finally:
            self._close_response(response)
            if temp_name is not None:
                try:
                    os.unlink(temp_name)
                except FileNotFoundError:
                    pass
                except OSError:
                    pass
            self._close_response(redirect_session)

    def _download_request(
        self,
        session: requests.Session,
        url: str,
        *,
        include_authorization: bool,
    ) -> requests.Response:
        headers = {
            "Accept": "application/octet-stream",
            "client-request-id": str(uuid4()),
        }
        if include_authorization:
            self._require_trusted_graph_url(url, "download URL")
            headers["Authorization"] = f"Bearer {self._access_token}"
        return session.request(
            "GET",
            url,
            headers=headers,
            stream=True,
            timeout=HTTP_TIMEOUT,
            verify=True,
            allow_redirects=False,
        )

    @staticmethod
    def _validate_upload_stream(stream: Any) -> None:
        source_stat = os.fstat(stream.fileno())
        if not stat.S_ISREG(source_stat.st_mode):
            raise LocalFileError("Upload source is not a file")
        if source_stat.st_size > MAX_SIMPLE_UPLOAD_SIZE:
            raise LocalFileError("Upload source exceeds the 250 MiB limit")

    @staticmethod
    def _remove_session_credentials(session: requests.Session) -> None:
        session.auth = None
        session.cert = None
        session.trust_env = False
        session.headers.clear()
        session.cookies.clear()
        session.params.clear()
        session.proxies.clear()

    @staticmethod
    def _require_safe_download_redirect(url: Any) -> None:
        try:
            parsed = urlsplit(url)
            port = parsed.port
        except (TypeError, ValueError) as exc:
            raise GraphError("Invalid download redirect") from exc
        if not (
            parsed.scheme == "https"
            and parsed.hostname
            and parsed.username is None
            and parsed.password is None
            and port in {None, 443}
        ):
            raise GraphError("Invalid download redirect")

    @staticmethod
    def _close_response(response: Any) -> None:
        close = getattr(response, "close", None)
        if callable(close):
            try:
                close()
            except Exception:
                pass

    @staticmethod
    def _item_url(
        drive_id: str, remote_path: str, *, encoded: bool = False
    ) -> str:
        encoded_drive_id = quote(drive_id, safe="")
        path = remote_path if encoded else encode_remote_path(remote_path)
        return f"{GRAPH_BASE_URL}/drives/{encoded_drive_id}/root:/{path}"

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