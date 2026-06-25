import os
import sqlite3
from pathlib import Path

from mysql.connector import Error, connect


def get_db_connection():
    mysql_host = os.getenv("MYSQL_HOST")
    if mysql_host:
        try:
            return connect(
                host=mysql_host,
                user=os.getenv("MYSQL_USER", "root"),
                password=os.getenv("MYSQL_PASSWORD", "password"),
                database=os.getenv("MYSQL_DATABASE", "dronemon"),
                auth_plugin="mysql_native_password",
            )
        except Error:
            pass

    sqlite_path = Path(__file__).resolve().parents[1] / "data.db"
    sqlite_path.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(sqlite_path, check_same_thread=False)
    connection.row_factory = sqlite3.Row
    return connection
