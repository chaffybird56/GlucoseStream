import os, sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

def test_index_route():
    import app as flask_app
    client = flask_app.app.test_client()
    resp = client.get('/')
    assert resp.status_code == 200


def test_patient_route_monkeypatched():
    import app as flask_app

    # Monkeypatch run_athena to return synthetic rows
    def fake_run(query: str):
        return [
            {"metric_date": "2025-09-29", "mean_glucose": "115", "tir_70_180": "0.82", "cv": "0.23", "gmi": "6.1"},
            {"metric_date": "2025-09-30", "mean_glucose": "118", "tir_70_180": "0.80", "cv": "0.22", "gmi": "6.2"},
        ]

    flask_app.run_athena = fake_run
    client = flask_app.app.test_client()
    resp = client.get('/patient?id=p1&days=2&dp=0')
    assert resp.status_code == 200
    assert b'Patient Metrics' in resp.data


