# DroneMon Backend

This backend is a FastAPI sample for the DroneMon Flutter application.

## Install

1. Create a virtual environment (recommended):

```bash
python3 -m venv .venv
source .venv/bin/activate
```

2. Install dependencies:

```bash
pip install -r requirements.txt
```

### Fallback if `venv` fails

If your system does not have `python3-venv`, use system pip instead:

```bash
python3 -m pip install --user -r requirements.txt
```

Then run the backend with system Python:

```bash
cd backend
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

## Run the server

```bash
cd backend
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

## API

- `GET /drone/{drone_id}`: Fetch drone status by ID.

## Notes

- The current backend uses in-memory sample data for quick testing.
- The Flutter app defaults to `http://localhost:8000` on desktop/web and `http://10.0.2.2:8000` on Android emulators.
- To point the app at a different backend host, pass `--dart-define=API_BASE_URL=http://<host>:8000` when you run Flutter.
- To connect a real MySQL database, configure environment variables:
  - `MYSQL_HOST`
  - `MYSQL_USER`
  - `MYSQL_PASSWORD`
  - `MYSQL_DATABASE`
