#python file used to train the model
import json
import numpy as np
from sklearn.neural_network import MLPClassifier

# 1. Synthetic Iloilo Corridor Dataset (10,000 samples)
# Inputs: [hour_norm (0..1), is_weekday (0/1), rain_norm (0..1), corridor_id_norm (0..1)]
np.random.seed(42)
N = 10000
hours = np.random.randint(0, 24, N)
days = np.random.randint(0, 7, N)
rain_mm = np.random.exponential(scale=2.5, size=N)
corridors = np.random.randint(0, 5, N) # 0:Ungka, 1:Jaro, 2:WVSU Luna, 3:Diversion/SM, 4:City Proper

X = np.column_stack([
    hours / 23.0,
    (days < 5).astype(float),
    np.clip(rain_mm / 15.0, 0.0, 1.0),
    corridors / 4.0
])

# Target Classes: 0 = Free Flow (Green), 1 = Moderate (Amber), 2 = Heavy Bottleneck (Red)
y = np.zeros(N, dtype=int)
for i in range(N):
    h, wd, r, c = hours[i], days[i] < 5, rain_mm[i], corridors[i]
    score = 0
    if wd and ((7 <= h <= 9) or (16 <= h <= 19)):
        score += 2
    elif (10 <= h <= 15) or (not wd and 14 <= h <= 18):
        score += 1
    if r > 3.0: # Iloilo downpours stall loading/unloading zones
        score += 1
    if c in [1, 2, 3] and wd and (7 <= h <= 8 or 17 <= h <= 18): # Jaro, WVSU, SM bottlenecks
        score += 1
    y[i] = min(score, 2)

# 2. Train lightweight 2-layer MLP
clf = MLPClassifier(hidden_layer_sizes=(12, 8), activation='relu', max_iter=300, random_state=42)
clf.fit(X, y)

# 3. Export weights & biases to JSON for universal Dart inference (Web + Mobile + Desktop)
model_data = {
    "w1": clf.coefs_[0].tolist(),
    "b1": clf.intercepts_[0].tolist(),
    "w2": clf.coefs_[1].tolist(),
    "b2": clf.intercepts_[1].tolist(),
    "w3": clf.coefs_[2].tolist(),
    "b3": clf.intercepts_[2].tolist(),
}

with open("iloilo_traffic_weights.json", "w") as f:
    json.dump(model_data, f)

print(f"Model trained! Validation accuracy: {clf.score(X, y):.2%}")