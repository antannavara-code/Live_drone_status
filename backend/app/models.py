from dataclasses import dataclass

@dataclass
class DroneRow:
    drone_id: str
    battery: str
    battery_health: str
    gps: str
    camera: str
    motors: str
    jetson: str
    telemetry: str
    altitude: str
    status: str
    video_feed: str
