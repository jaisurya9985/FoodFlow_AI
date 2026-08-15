from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List
import numpy as np
from math import radians, sin, cos, sqrt, atan2
import os
import joblib

app = FastAPI(title="FoodBridge AI ML Server", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Load Models at Startup ───────────────────────────────────────────────────
# The .pkl files are in the same directory as main.py
MODEL_DIR = os.path.dirname(__file__)

food_risk_model = None
category_encoder = None
volunteer_model = None

def load_models():
    global food_risk_model, category_encoder, volunteer_model
    try:
        food_risk_model = joblib.load(os.path.join(MODEL_DIR, "food_risk_model.pkl"))
        category_encoder = joblib.load(os.path.join(MODEL_DIR, "category_encoder.pkl"))
        volunteer_model = joblib.load(os.path.join(MODEL_DIR, "volunteer_model.pkl"))
        print("ML models loaded successfully.")
    except FileNotFoundError as e:
        print(f"Model files not found: {e}")
        print("Place .pkl files in ml_server/ and restart.")
    except Exception as e:
        import traceback
        print(f"Error loading models: {e}")
        traceback.print_exc()

load_models()

# ─── Request / Response Models ────────────────────────────────────────────────

class FoodRiskRequest(BaseModel):
    category: str
    storage_temperature_C: float
    max_fridge_days: float
    time_since_cooked: float

class Volunteer(BaseModel):
    vol_id: str
    lat: float
    lng: float
    rating: float
    deliveries_done: int
    has_vehicle: bool
    is_available: bool

class VolunteerMatchRequest(BaseModel):
    pickup_lat: float
    pickup_lng: float
    food_weight_kg: float
    expiry_hours: float
    volunteers: List[Volunteer]


# ─── Utilities ────────────────────────────────────────────────────────────────

def haversine(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    earth_radius_km = 6371.0
    dlat = radians(lat2 - lat1)
    dlng = radians(lng2 - lng1)
    a = min(1.0, max(0.0,
        sin(dlat / 2) ** 2
        + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlng / 2) ** 2
    ))
    return earth_radius_km * 2 * atan2(sqrt(a), sqrt(1 - a))


def fallback_food_risk(category: str, temp: float, time_since_cooked: float, max_fridge_days: float) -> dict:
    total_shelf_hours = max_fridge_days * 24 if max_fridge_days > 0 else 12.0
    shelf_used_ratio = time_since_cooked / total_shelf_hours

    is_perishable = category in ("cooked_meal", "dairy")

    temp_danger_score = 0.0
    if temp > 35: temp_danger_score = 0.8
    elif temp > 25: temp_danger_score = 0.5
    elif temp > 15: temp_danger_score = 0.2

    perishable_exposure_score = 0.0
    if is_perishable and temp > 10:
        safe_hours = 4.0 if temp < 30 else 2.0
        perishable_exposure_score = time_since_cooked / safe_hours

    combined_risk_score = shelf_used_ratio * 0.35 + temp_danger_score * 0.3 + perishable_exposure_score * 0.35

    if is_perishable and time_since_cooked > 6.0 and temp > 20:
        combined_risk_score = max(combined_risk_score, 1.0)

    if shelf_used_ratio >= 1.0:
        combined_risk_score = max(combined_risk_score, 1.0)

    if combined_risk_score >= 1.0:
        return {"risk": 3, "risk_label": "SPOILED", "confidence": 92.0, "expiry_minutes": 0}
    elif combined_risk_score >= 0.75:
        return {"risk": 2, "risk_label": "HIGH", "confidence": 80.0, "expiry_minutes": 60}
    elif combined_risk_score >= 0.4:
        return {"risk": 1, "risk_label": "MEDIUM", "confidence": 75.0, "expiry_minutes": 240}
    else:
        return {"risk": 0, "risk_label": "LOW", "confidence": 85.0, "expiry_minutes": 720}

# ─── Endpoints ────────────────────────────────────────────────────────────────

@app.post("/predict/food-risk")
def predict_food_risk(req: FoodRiskRequest):
    risk_map = {0: "Low Risk", 1: "Medium Risk", 2: "High Risk", 3: "Spoiled"}
    logical_risk = fallback_food_risk(req.category, req.storage_temperature_C, req.time_since_cooked, req.max_fridge_days)
    if logical_risk["risk"] == 3:
        return logical_risk
    if food_risk_model is None or category_encoder is None:
        return logical_risk
    try:
        cat_encoded = category_encoder.transform([req.category])[0]
        features = np.array([[ cat_encoded, req.storage_temperature_C, req.max_fridge_days, req.time_since_cooked ]])

        raw_pred = food_risk_model.predict(features)[0]

        try:
            model_prediction = int(raw_pred)
        except (ValueError, TypeError):
            val_lower = str(raw_pred).lower()
            if "high" in val_lower: model_prediction = 2
            elif "medium" in val_lower: model_prediction = 1
            elif "low" in val_lower: model_prediction = 0
            else: model_prediction = logical_risk["risk"]

        proba = food_risk_model.predict_proba(features)[0]
        model_confidence = float(max(proba) * 100)
        logical_risk_value = logical_risk["risk"]
        final_risk = max(model_prediction, logical_risk_value)
        final_confidence = max(model_confidence, logical_risk["confidence"])
        ex_mins = 480
        if final_risk == 2: ex_mins = 60
        elif final_risk == 1: ex_mins = 180
        final_expiry = min(ex_mins, logical_risk.get("expiry_minutes", 480))
        return { "risk": final_risk, "risk_label": risk_map.get(final_risk, "Unknown"), "confidence": final_confidence, "expiry_minutes": final_expiry }
    except Exception as e:
        print(f"Prediction error: {e}")
        return logical_risk

@app.post("/predict/volunteer-match")
def predict_volunteer_match(req: VolunteerMatchRequest):
    results = []

    for v in req.volunteers:
        if not v.is_available:
            continue

        dist = haversine(req.pickup_lat, req.pickup_lng, v.lat, v.lng)

        try:
            if volunteer_model is not None:
                features = np.array([[
                    dist,
                    req.expiry_hours,
                    req.food_weight_kg,
                    v.rating,
                    int(v.is_available),
                    int(v.has_vehicle),
                    1
                ]])
                proba = volunteer_model.predict_proba(features)[0][1]
                score = int(proba * 100)
            else:
                cap_match = 1.0 if (v.has_vehicle or req.food_weight_kg < 15) else 0.3
                proximity_score = max(0, 1 - dist / 10)
                score = int((proximity_score * 0.5 + (v.rating / 5) * 0.3 + cap_match * 0.2) * 100)

        except Exception as e:
            print(f"Volunteer prediction error: {e}")
            score = 75

        results.append({
            "vol_id": v.vol_id,
            "match_score": min(score, 99),
            "distance_km": round(dist, 2),
        })

    results.sort(key=lambda x: x["match_score"], reverse=True)
    return {"matches": results[:3]}

@app.get("/health")
def health():
    return {
        "status": "ok",
        "models_loaded": {
            "food_risk": food_risk_model is not None,
            "category_encoder": category_encoder is not None,
            "volunteer_matcher": volunteer_model is not None,
        },
    }


@app.get("/")
def root():
    return {
        "name": "FoodBridge AI ML Server",
        "version": "1.0.0",
        "endpoints": [
            "POST /predict/food-risk",
            "POST /predict/volunteer-match",
            "GET  /health",
        ],
    }
