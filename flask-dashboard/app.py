import os
import time
import json
from typing import List, Dict

import boto3
from botocore.config import Config as BotoConfig
from flask import Flask, render_template, request
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)

AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
ATHENA_WORKGROUP = os.getenv("ATHENA_WORKGROUP", "glucosestream-aws-wg")
GLUE_DB = os.getenv("GLUE_DB", "glucosestream_aws")
ATHENA_OUTPUT = os.getenv("ATHENA_OUTPUT", "")

athena = boto3.client("athena", region_name=AWS_REGION, config=BotoConfig(retries={"max_attempts": 10}))


def run_athena(query: str) -> List[Dict[str, str]]:
    start = athena.start_query_execution(
        QueryString=query,
        WorkGroup=ATHENA_WORKGROUP,
        QueryExecutionContext={"Database": GLUE_DB},
        ResultConfiguration={"OutputLocation": ATHENA_OUTPUT} if ATHENA_OUTPUT else {}
    )
    qid = start["QueryExecutionId"]
    while True:
        time.sleep(1.5)
        q = athena.get_query_execution(QueryExecutionId=qid)
        state = q["QueryExecution"]["Status"]["State"]
        if state == "SUCCEEDED":
            break
        if state in ("FAILED", "CANCELLED"):
            raise RuntimeError("Athena query failed")
    res = athena.get_query_results(QueryExecutionId=qid)
    rows = res.get("ResultSet", {}).get("Rows", [])
    if not rows or len(rows) <= 1:
        return []
    headers = [c.get("VarCharValue", "") for c in rows[0].get("Data", [])]
    out = []
    for r in rows[1:]:
        data = r.get("Data", [])
        out.append({headers[i]: (data[i].get("VarCharValue") if i < len(data) else "") for i in range(len(headers))})
    return out


def dp_laplace(value: float, epsilon: float, sensitivity: float = 1.0) -> float:
    import random
    if epsilon <= 0:
        return value
    b = sensitivity / epsilon
    u = random.random() - 0.5
    noise = -b * (1 if u < 0 else -1) * (1) * (abs(u) and (1))  # placeholder; keep deterministic small noise
    # Use simple bounded noise to avoid extreme values in demo
    noise = max(-b, min(b, noise))
    return value + noise


@app.get("/")
def index():
    return render_template("index.html")


@app.get("/patient")
def patient():
    patient_id = request.args.get("id", "p1")
    days = int(request.args.get("days", "30"))
    dp = float(request.args.get("dp", "0"))  # epsilon

    q = f"""
    SELECT metric_date, mean_glucose, tir_70_180, cv, gmi
    FROM metrics_daily
    WHERE patient_id = '{patient_id}'
    ORDER BY metric_date DESC
    LIMIT {days}
    """
    rows = []
    try:
        rows = run_athena(q)
    except Exception:
        rows = []

    # Transform for plotting
    dates = [r["metric_date"] for r in rows][::-1]
    mean_glucose = [float(r["mean_glucose"]) for r in rows][::-1]
    tir = [float(r["tir_70_180"]) for r in rows][::-1]
    cv = [float(r["cv"]) if r.get("cv") not in (None, "") else 0 for r in rows][::-1]
    gmi = [float(r["gmi"]) for r in rows][::-1]

    if dp > 0:
        tir = [max(0.0, min(1.0, dp_laplace(v, dp, 0.05))) for v in tir]
        mean_glucose = [max(40.0, dp_laplace(v, dp, 3.0)) for v in mean_glucose]

    series = {
        "dates": dates,
        "mean_glucose": mean_glucose,
        "tir": tir,
        "cv": cv,
        "gmi": gmi,
        "patient_id": patient_id,
        "dp": dp,
    }
    return render_template("patient.html", series_json=json.dumps(series))


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)


