import sqlite3
from typing import List

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from .database import get_db_connection
from .schemas import DroneStatusResponse, FlightResponse

app = FastAPI(
    title="DroneMon Backend API",
    description="API for fetching drone telemetry and health status.",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

SAMPLE_DRONES = [
    {
        "drone_id": "DRONE-001",
        "battery": "24.8 V",
        "battery_health": "Good Health",
        "gps": "Connected",
        "camera": "Active",
        "motors": "4/4 Working",
        "jetson": "Connected",
        "telemetry": "Connected",
        "altitude": "120.5 m",
        "status": "READY",
        "video_feed": "Active",
    },
    {
        "drone_id": "DRONE-002",
        "battery": "23.6 V",
        "battery_health": "Good Health",
        "gps": "Connected",
        "camera": "Active",
        "motors": "4/4 Working",
        "jetson": "Connected",
        "telemetry": "Connected",
        "altitude": "0 m",
        "status": "STANDBY",
        "video_feed": "Active",
    },
    {
        "drone_id": "DRONE-003",
        "battery": "22.9 V",
        "battery_health": "Fair Health",
        "gps": "Connected",
        "camera": "Active",
        "motors": "4/4 Working",
        "jetson": "Connected",
        "telemetry": "Connected",
        "altitude": "50.2 m",
        "status": "FLYING",
        "video_feed": "Active",
    },
]

SQL_CREATE_TABLE = """
CREATE TABLE IF NOT EXISTS drones (
    drone_id TEXT PRIMARY KEY,
    battery TEXT,
    battery_health TEXT,
    gps TEXT,
    camera TEXT,
    motors TEXT,
    jetson TEXT,
    telemetry TEXT,
    altitude TEXT,
    status TEXT,
    video_feed TEXT
)
"""

SQL_CREATE_FLIGHTS = """
CREATE TABLE IF NOT EXISTS flights (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    drone_id TEXT NOT NULL,
    mission_name TEXT,
    flown_at TEXT,
    distance TEXT,
    status TEXT,
    FOREIGN KEY(drone_id) REFERENCES drones(drone_id)
)
"""

@app.on_event("startup")
def startup_event():
    initialize_database()


def _is_sqlite_connection(conn) -> bool:
    return isinstance(conn, sqlite3.Connection)


def _build_insert_query(conn):
    if _is_sqlite_connection(conn):
        placeholders = ", ".join(["?" for _ in range(11)])
        return f"""
        INSERT OR REPLACE INTO drones (
            drone_id, battery, battery_health, gps, camera, motors,
            jetson, telemetry, altitude, status, video_feed
        ) VALUES ({placeholders})
        """

    placeholders = ", ".join(["%s" for _ in range(11)])
    return """
        INSERT INTO drones (
            drone_id, battery, battery_health, gps, camera, motors,
            jetson, telemetry, altitude, status, video_feed
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON DUPLICATE KEY UPDATE
            battery=VALUES(battery),
            battery_health=VALUES(battery_health),
            gps=VALUES(gps),
            camera=VALUES(camera),
            motors=VALUES(motors),
            jetson=VALUES(jetson),
            telemetry=VALUES(telemetry),
            altitude=VALUES(altitude),
            status=VALUES(status),
            video_feed=VALUES(video_feed)
        """


def initialize_database():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute(SQL_CREATE_TABLE)
    cursor.execute(SQL_CREATE_FLIGHTS)
    conn.commit()

    cursor.execute("SELECT COUNT(*) FROM drones")
    row = cursor.fetchone()
    count = row[0] if row is not None else 0
    if count == 0:
        insert_sample_data(cursor, conn)
    else:
        update_sample_battery_units(cursor, conn)

    cursor.execute("SELECT COUNT(*) FROM flights")
    row = cursor.fetchone()
    count = row[0] if row is not None else 0
    if count == 0:
        insert_sample_flight_data(cursor, conn)

    conn.commit()
    cursor.close()
    conn.close()


def insert_sample_data(cursor, conn):
    insert_sql = _build_insert_query(conn)
    cursor.executemany(
        insert_sql,
        [
            (
                drone["drone_id"],
                drone["battery"],
                drone["battery_health"],
                drone["gps"],
                drone["camera"],
                drone["motors"],
                drone["jetson"],
                drone["telemetry"],
                drone["altitude"],
                drone["status"],
                drone["video_feed"],
            )
            for drone in SAMPLE_DRONES
        ],
    )


def update_sample_battery_units(cursor, conn):
    placeholder = "?" if _is_sqlite_connection(conn) else "%s"
    update_sql = f"UPDATE drones SET battery = {placeholder} WHERE drone_id = {placeholder}"
    cursor.executemany(
        update_sql,
        [
            (drone["battery"], drone["drone_id"])
            for drone in SAMPLE_DRONES
        ],
    )


def insert_sample_flight_data(cursor, conn):
    insert_sql = _build_flight_insert_query(conn)
    cursor.executemany(
        insert_sql,
        [
            ("DRONE-001", "Pipeline Patrol", "2026-05-25 14:20", "12.4 km", "Completed"),
            ("DRONE-001", "Inspection Run", "2026-05-24 09:55", "5.2 km", "Completed"),
            ("DRONE-002", "Standby Check", "2026-05-25 11:10", "0.0 km", "Standby"),
            ("DRONE-003", "Survey Mission", "2026-05-23 17:30", "8.9 km", "Completed"),
            ("DRONE-003", "Waypoint Sweep", "2026-05-22 13:45", "7.6 km", "Completed"),
        ],
    )


def _build_flight_insert_query(conn):
    if _is_sqlite_connection(conn):
        placeholders = ", ".join(["?" for _ in range(5)])
        return f"INSERT INTO flights (drone_id, mission_name, flown_at, distance, status) VALUES ({placeholders})"

    placeholders = ", ".join(["%s" for _ in range(5)])
    return "INSERT INTO flights (drone_id, mission_name, flown_at, distance, status) VALUES (%s, %s, %s, %s, %s)"


def _build_drone_response(row) -> DroneStatusResponse:
    if isinstance(row, sqlite3.Row):
        row = dict(row)
    return DroneStatusResponse(**row)


def _build_flight_response(row) -> FlightResponse:
    if isinstance(row, sqlite3.Row):
        row = dict(row)
    return FlightResponse(**row)


@app.get("/drones", response_model=List[DroneStatusResponse])
async def list_drones():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM drones ORDER BY drone_id")
    rows = cursor.fetchall()
    cursor.close()
    conn.close()
    return [_build_drone_response(row) for row in rows]


@app.get("/drone/{drone_id}", response_model=DroneStatusResponse)
async def get_drone_status(drone_id: str):
    conn = get_db_connection()
    cursor = conn.cursor()
    placeholder = "?" if _is_sqlite_connection(conn) else "%s"
    cursor.execute(f"SELECT * FROM drones WHERE drone_id = {placeholder}", (drone_id,))
    row = cursor.fetchone()
    cursor.close()
    conn.close()
    if row is None:
        raise HTTPException(status_code=404, detail="Drone not found")
    return _build_drone_response(row)


@app.get("/drone/{drone_id}/flights", response_model=List[FlightResponse])
async def get_drone_flights(drone_id: str):
    conn = get_db_connection()
    cursor = conn.cursor()
    placeholder = "?" if _is_sqlite_connection(conn) else "%s"
    cursor.execute(f"SELECT mission_name, flown_at, distance, status FROM flights WHERE drone_id = {placeholder} ORDER BY flown_at DESC", (drone_id,))
    rows = cursor.fetchall()
    cursor.close()
    conn.close()
    return [_build_flight_response(row) for row in rows]
