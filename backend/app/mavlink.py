import os

from typing import Dict, Optional

try:
    from pymavlink import mavutil
except ImportError:  # pragma: no cover
    mavutil = None


def connect_mavlink(connection_uri: Optional[str] = None):
    if mavutil is None:
        raise RuntimeError("pymavlink is not installed")

    uri = connection_uri or os.getenv("MAVLINK_URI", "udp:127.0.0.1:14550")
    return mavutil.mavlink_connection(uri)


def fetch_mavlink_status(connection_uri: Optional[str] = None) -> Dict[str, str]:
    if mavutil is None:
        return {
            "connected": "false",
            "reason": "pymavlink not installed",
        }

    try:
        master = connect_mavlink(connection_uri)
        heartbeat = master.wait_heartbeat(timeout=3)
        if heartbeat is None:
            return {"connected": "false", "reason": "timeout"}

        return {
            "connected": "true",
            "system_id": str(master.target_system),
            "component_id": str(master.target_component),
            "type": str(heartbeat.type),
        }
    except Exception as exc:
        return {"connected": "false", "reason": str(exc)}
