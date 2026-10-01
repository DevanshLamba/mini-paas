"""Runtime settings read from environment variables (12-factor style).

Kubernetes injects these through the Deployment manifest, so the same image runs
unchanged in docker-compose, k3d and CI.
"""

import os
import socket
from dataclasses import dataclass


def _env_bool(name: str, default: bool) -> bool:
    return os.getenv(name, str(default)).strip().lower() in {"1", "true", "yes", "on"}


@dataclass(frozen=True)
class Settings:
    version: str = "dev"
    log_level: str = "INFO"
    access_log: bool = True
    work_default_iterations: int = 100_000
    work_max_iterations: int = 2_000_000
    fault_injection: bool = False
    pod_name: str = socket.gethostname()

    @classmethod
    def from_env(cls) -> "Settings":
        return cls(
            version=os.getenv("APP_VERSION", cls.version),
            log_level=os.getenv("LOG_LEVEL", cls.log_level).upper(),
            access_log=_env_bool("ACCESS_LOG", cls.access_log),
            work_default_iterations=int(
                os.getenv("WORK_DEFAULT_ITERATIONS", cls.work_default_iterations)
            ),
            work_max_iterations=int(os.getenv("WORK_MAX_ITERATIONS", cls.work_max_iterations)),
            fault_injection=_env_bool("FAULT_INJECTION", cls.fault_injection),
            pod_name=os.getenv("POD_NAME", cls.pod_name),
        )
