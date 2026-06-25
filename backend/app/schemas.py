from pydantic import BaseModel

class DroneStatusResponse(BaseModel):
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


class FlightResponse(BaseModel):
    mission_name: str
    flown_at: str
    distance: str
    status: str
