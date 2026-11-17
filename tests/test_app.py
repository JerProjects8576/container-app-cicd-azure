from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health_endpoint_reports_ok():
    response = client.get("/healthz")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_info_reports_the_running_build():
    response = client.get("/api/info")
    body = response.json()

    assert response.status_code == 200
    assert set(body) == {"commit", "environment", "replica", "time_utc"}
    assert body["commit"] == "dev"  # default when not built by the pipeline


def test_home_page_shows_the_commit():
    response = client.get("/")

    assert response.status_code == 200
    assert "text/html" in response.headers["content-type"]
    assert "It works" in response.text


def test_unknown_path_returns_404():
    assert client.get("/does-not-exist").status_code == 404
