import time

from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Weather API (Fake)", version="0.1.0", docs_url="/")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/healthz")
def healthz():
    return {"status": "ok", "ts": int(time.time())}


@app.get("/weather")
def get_weather(
    lat: float = Query(..., description="Latitude"),
    lon: float = Query(..., description="Longitude"),
    units: str = Query("metric", pattern="^(metric|imperial)$"),
    city: str | None = Query(None, description="Optional city label"),
):
    """
    Return fake current weather shaped roughly like OpenWeatherMap's 'Current Weather Data'.
    Times are Unix UTC seconds. Fields mirror familiar real-world names to ease client swap.
    """
    now = int(time.time())
    sample = {
        "coord": {"lon": lon, "lat": lat},
        "weather": [{"id": 800, "main": "Clear", "description": "clear sky", "icon": "01d"}],
        "base": "stations",
        "main": {
            "temp": 23.5 if units == "metric" else 74.3,
            "feels_like": 24.1 if units == "metric" else 75.4,
            "pressure": 1012,
            "humidity": 48,
            "temp_min": 22.0 if units == "metric" else 71.6,
            "temp_max": 25.0 if units == "metric" else 77.0,
        },
        "visibility": 10000,
        "wind": {"speed": 3.6 if units == "metric" else 8.1, "deg": 180},
        "clouds": {"all": 0},
        "dt": now,
        "sys": {
            "country": "GB",
            "sunrise": now - 6 * 3600,
            "sunset": now + 6 * 3600,
        },
        "timezone": 0,
        "id": 2643743,
        "name": city or "London",
        "cod": 200,
        "units": units,
    }
    return sample
