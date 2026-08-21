"""Train and evaluate the FoodBridge food-risk classifier.

The source CSV provides category, storage temperature, maximum fridge life,
and a risk label.  It does not contain a time-since-cooked field, so this
model intentionally uses only the three supported, labelled inputs.
"""

from pathlib import Path
import re

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (
    accuracy_score,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
)
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder


BASE_DIR = Path(__file__).resolve().parent
CSV_PATH = BASE_DIR / "food_spoilage.csv"
MODEL_PATH = BASE_DIR / "food_risk_model.pkl"
ENCODER_PATH = BASE_DIR / "category_encoder.pkl"
RANDOM_STATE = 42


def parse_temperature(value: object) -> float:
    """Extract a conservative numeric Celsius value from source text."""
    text = str(value).lower().replace("≤", "<=").strip()
    if "room" in text:
        return 25.0
    numbers = [float(number) for number in re.findall(r"-?\d+(?:\.\d+)?", text)]
    if not numbers:
        return 5.0
    # Values containing freezer temperatures such as "<=4 / -18" are stored
    # safely at the colder end; the highest value captures the risk-relevant
    # refrigerator temperature for this application.
    return max(numbers)


def normalise_risk(value: object) -> str:
    text = str(value).lower()
    if "high" in text:
        return "high"
    if "medium" in text:
        return "medium"
    raise ValueError(f"Unsupported risk label: {value!r}")


def main() -> None:
    data = pd.read_csv(CSV_PATH)
    data["risk_label"] = data["risk"].map(normalise_risk)
    data["storage_temperature_numeric"] = data["storage_temperature_C"].map(parse_temperature)
    data["max_fridge_days_numeric"] = pd.to_numeric(
        data["max_fridge_days"], errors="coerce"
    ).fillna(0.0)

    category_encoder = LabelEncoder()
    category = category_encoder.fit_transform(data["category"])
    features = np.column_stack(
        [category, data["storage_temperature_numeric"], data["max_fridge_days_numeric"]]
    )
    labels = data["risk_label"]

    x_train, x_test, y_train, y_test = train_test_split(
        features,
        labels,
        test_size=0.20,
        random_state=RANDOM_STATE,
        stratify=labels,
    )
    model = RandomForestClassifier(
        n_estimators=300,
        random_state=RANDOM_STATE,
        class_weight="balanced",
        n_jobs=-1,
    )
    model.fit(x_train, y_train)
    predictions = model.predict(x_test)
    probabilities = model.predict_proba(x_test)
    high_index = list(model.classes_).index("high")

    metrics = {
        "test_samples": int(len(y_test)),
        "accuracy": accuracy_score(y_test, predictions),
        "precision_weighted": precision_score(y_test, predictions, average="weighted", zero_division=0),
        "recall_weighted": recall_score(y_test, predictions, average="weighted", zero_division=0),
        "f1_weighted": f1_score(y_test, predictions, average="weighted", zero_division=0),
        "roc_auc_high_risk": roc_auc_score((y_test == "high").astype(int), probabilities[:, high_index]),
        "classes": model.classes_.tolist(),
        "confusion_matrix": confusion_matrix(y_test, predictions, labels=model.classes_).tolist(),
    }

    joblib.dump(model, MODEL_PATH)
    joblib.dump(category_encoder, ENCODER_PATH)
    print(metrics)


if __name__ == "__main__":
    main()
