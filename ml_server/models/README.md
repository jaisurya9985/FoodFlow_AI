# ML Model Files

Place the following trained model files in this directory:

- `food_risk_model.pkl`    — Scikit-learn classifier (predicts risk: 0=LOW, 1=MEDIUM, 2=HIGH)
- `category_encoder.pkl`   — LabelEncoder fitted on food categories
- `volunteer_matcher.pkl`  — Scikit-learn classifier (predicts volunteer suitability score)

## Starting the server (with models)

```bash
cd ml_server
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

## Testing (without models)
The server runs without .pkl files using built-in heuristics.
Check http://localhost:8000/health to see model load status.
