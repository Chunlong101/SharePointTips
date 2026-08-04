from enum import IntEnum


class ExitCode(IntEnum):
    OK = 0
    UNEXPECTED = 1
    USAGE = 2
    CONFIG = 10
    AUTH = 20
    GRAPH = 30
    LOCAL_FILE = 40


class DemoError(Exception):
    exit_code = ExitCode.UNEXPECTED

    def __init__(self, safe_message: str) -> None:
        super().__init__(safe_message)


class ConfigError(DemoError):
    exit_code = ExitCode.CONFIG


class AuthError(DemoError):
    exit_code = ExitCode.AUTH


class GraphError(DemoError):
    exit_code = ExitCode.GRAPH


class LocalFileError(DemoError):
    exit_code = ExitCode.LOCAL_FILE
