"""FoodWise multi-label intent classifier: class-weighted Keras training.

Run from the project root:
    python ml/train_model.py

Input: ml/training_data_clean.csv (columns: text,labels)
Outputs: assets/ai/*.tflite and JSON, ml/*.keras, history and metrics.
"""

import json
import os
import re
import string
from pathlib import Path

os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"

import numpy as np
import pandas as pd
import tensorflow as tf
from tensorflow import keras
from iterstrat.ml_stratifiers import MultilabelStratifiedShuffleSplit
from sklearn.metrics import precision_recall_fscore_support


ROOT = Path(__file__).resolve().parent.parent
DATA_FILE = ROOT / "ml" / "training_data_clean.csv"
ML_DIR = ROOT / "ml"
AI_DIR = ROOT / "assets" / "ai"

SEED = 42
MAX_WORDS = 2000
SEQUENCE_LENGTH = 32
EPOCHS = 150
BATCH_SIZE = 16

LABELS = [
    "meal_breakfast", "meal_lunch", "meal_dinner", "meal_snack",
    "pref_chicken", "pref_fish", "pref_vegetables", "pref_rice",
    "pref_noodles", "pref_egg", "pref_fruit",
    "avoid_spicy", "avoid_dairy", "avoid_peanuts", "avoid_seafood",
    "avoid_egg", "avoid_gluten", "diet_vegetarian", "diet_vegan",
    "budget_friendly", "filling", "allergy_peanuts", "allergy_dairy",
    "allergy_seafood", "allergy_egg", "allergy_gluten",
    "restriction_gluten",
]

keras.utils.set_random_seed(SEED)


def normalize(text):
    text = str(text).lower()
    text = text.translate(str.maketrans("", "", string.punctuation))
    return re.sub(r"\s+", " ", text).strip()


def load_data():
    df = pd.read_csv(DATA_FILE, encoding="utf-8-sig")
    if not {"text", "labels"}.issubset(df.columns):
        raise ValueError("CSV must contain 'text' and 'labels' columns.")
    if df[["text", "labels"]].isna().any().any():
        raise ValueError("Found empty CSV fields.")

    texts = [normalize(text) for text in df["text"]]
    if not all(texts) or len(texts) != len(set(texts)):
        raise ValueError("Found empty or duplicate requests. Recheck your CSV.")

    targets = np.zeros((len(texts), len(LABELS)), dtype=np.float32)
    label_to_index = {name: idx for idx, name in enumerate(LABELS)}
    for row, cell in enumerate(df["labels"]):
        parts = [item.strip() for item in str(cell).split("|") if item.strip()]
        if not parts:
            raise ValueError(f"Row {row + 2} has no labels.")
        for label in parts:
            if label not in label_to_index:
                raise ValueError(f"Unknown label '{label}' at CSV row {row + 2}.")
            targets[row, label_to_index[label]] = 1.0

    counts = targets.sum(axis=0)
    if np.any(counts < 5):
        too_rare = [LABELS[i] for i in np.where(counts < 5)[0]]
        raise ValueError(f"Add examples for rare labels: {too_rare}")

    print(f"Dataset: {len(texts)} unique examples | {len(LABELS)} labels")
    return texts, targets


def split_indices(targets):
    dummy = np.zeros((len(targets), 1))
    first = MultilabelStratifiedShuffleSplit(
        n_splits=1, test_size=0.20, random_state=SEED
    )
    train_val_idx, test_idx = next(first.split(dummy, targets))

    second = MultilabelStratifiedShuffleSplit(
        n_splits=1, test_size=0.15, random_state=SEED
    )
    inner_train, inner_val = next(
        second.split(np.zeros((len(train_val_idx), 1)), targets[train_val_idx])
    )
    train_idx = train_val_idx[inner_train]
    val_idx = train_val_idx[inner_val]

    print(f"Split: {len(train_idx)} train / {len(val_idx)} validation / "
          f"{len(test_idx)} test")
    return train_idx, val_idx, test_idx


def tokenize(texts, train_idx):
    vectorizer = keras.layers.TextVectorization(
        max_tokens=MAX_WORDS,
        output_mode="int",
        output_sequence_length=SEQUENCE_LENGTH,
        standardize=None,
        split="whitespace",
    )
    vectorizer.adapt(np.asarray([texts[i] for i in train_idx], dtype=str))
    vocabulary = vectorizer.get_vocabulary()
    tokens = vectorizer(np.asarray(texts, dtype=str)).numpy().astype(np.int32)
    print(f"Vocabulary size: {len(vocabulary)}")
    return tokens, vocabulary


def weighted_loss_for(y_train):
    """Increase the cost of missing positive labels; train data only."""
    positive = y_train.sum(axis=0)
    negative = len(y_train) - positive
    positive_weights = np.clip(negative / np.maximum(positive, 1), 1, 12)
    weights = tf.constant(positive_weights, dtype=tf.float32)

    print("Positive class weights (min/max):",
          round(float(positive_weights.min()), 2),
          round(float(positive_weights.max()), 2))

    def weighted_binary_crossentropy(y_true, y_pred):
        y_true = tf.cast(y_true, tf.float32)
        p = tf.clip_by_value(y_pred, 1e-7, 1.0 - 1e-7)
        pos_term = -y_true * tf.math.log(p) * weights
        neg_term = -(1.0 - y_true) * tf.math.log(1.0 - p)
        return tf.reduce_mean(pos_term + neg_term, axis=-1)

    return weighted_binary_crossentropy


def build_model(vocab_size, y_train):
    inputs = keras.Input(
        shape=(SEQUENCE_LENGTH,), dtype="int32", name="token_ids"
    )
    x = keras.layers.Embedding(
        input_dim=vocab_size, output_dim=48, mask_zero=True
    )(inputs)
    x = keras.layers.GlobalAveragePooling1D()(x)
    x = keras.layers.Dense(96, activation="relu")(x)
    x = keras.layers.Dropout(0.15)(x)
    x = keras.layers.Dense(48, activation="relu")(x)
    outputs = keras.layers.Dense(
        len(LABELS), activation="sigmoid", name="label_probabilities"
    )(x)

    model = keras.Model(inputs, outputs, name="FoodWiseIntentClassifier")
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=0.002),
        loss=weighted_loss_for(y_train),
    )
    model.summary()
    return model


def score(y_true, probabilities, threshold):
    predictions = (probabilities >= threshold).astype(np.int32)
    p, r, f, _ = precision_recall_fscore_support(
        y_true, predictions, average="micro", zero_division=0
    )
    return float(p), float(r), float(f), predictions


def choose_threshold(y_val, probabilities):
    """Select ONE threshold on validation set only, never test set."""
    best_threshold = 0.50
    best_f1 = -1.0
    for threshold in np.arange(0.05, 0.801, 0.025):
        _, _, f1, _ = score(y_val, probabilities, threshold)
        if f1 > best_f1:
            best_f1 = f1
            best_threshold = float(round(threshold, 3))
    print(f"Validation-selected threshold: {best_threshold:.3f}")
    print(f"Validation micro F1: {best_f1:.4f}")
    return best_threshold


def evaluate(y_test, probabilities, threshold):
    micro_p, micro_r, micro_f1, pred = score(y_test, probabilities, threshold)
    per_p, per_r, per_f, support = precision_recall_fscore_support(
        y_test, pred, average=None, zero_division=0
    )
    macro_f1 = float(np.mean(per_f))
    exact_match = float(np.mean(np.all(pred == y_test, axis=1)))

    print("\n=== TEST RESULTS (held-out split) ===")
    print(f"Micro precision: {micro_p:.4f}")
    print(f"Micro recall:    {micro_r:.4f}")
    print(f"Micro F1:        {micro_f1:.4f}")
    print(f"Macro F1:        {macro_f1:.4f}")
    print(f"Exact match:     {exact_match:.4f}")
    print(f"Positive predictions: {int(pred.sum())} | "
          f"True positive labels: {int(y_test.sum())}")

    per_label = {}
    for i, name in enumerate(LABELS):
        per_label[name] = {
            "precision": float(per_p[i]),
            "recall": float(per_r[i]),
            "f1": float(per_f[i]),
            "support": int(support[i]),
        }
        print(f"{name:24} F1={per_f[i]:.3f}  support={int(support[i])}")

    return {
        "test_examples": int(len(y_test)),
        "threshold": float(threshold),
        "micro_precision": micro_p,
        "micro_recall": micro_r,
        "micro_f1": micro_f1,
        "macro_f1": macro_f1,
        "exact_match_accuracy": exact_match,
        "per_label": per_label,
    }


def save_json(path, value):
    with open(path, "w", encoding="utf-8") as out:
        json.dump(value, out, indent=2, ensure_ascii=False)


def export_model(model, vocabulary, threshold):
    # Save an inference-only copy without the custom training loss.
    inference_model = keras.Model(
        inputs=model.inputs,
        outputs=model.outputs,
        name="FoodWiseIntentClassifier",
    )
    inference_model.save(ML_DIR / "foodwise_intent.keras")

    converter = tf.lite.TFLiteConverter.from_keras_model(inference_model)
    tflite_bytes = converter.convert()
    (AI_DIR / "foodwise_intent.tflite").write_bytes(tflite_bytes)

    save_json(AI_DIR / "vocabulary.json", {
        "vocabulary": vocabulary,
        "max_sequence_length": SEQUENCE_LENGTH,
        "normalization": "lowercase, remove ASCII punctuation, collapse whitespace",
    })
    save_json(AI_DIR / "labels.json", LABELS)
    save_json(AI_DIR / "model_config.json", {
        "model_name": "FoodWise Intent Classifier",
        "model_type": "multi_label_text_classifier",
        "input_dtype": "int32",
        "input_shape": [1, SEQUENCE_LENGTH],
        "output_shape": [1, len(LABELS)],
        "confidence_threshold": threshold,
        "number_of_labels": len(LABELS),
    })

    # Ensure the converted model can perform one complete inference.
    interpreter = tf.lite.Interpreter(model_content=tflite_bytes)
    interpreter.allocate_tensors()
    inp = interpreter.get_input_details()[0]
    out = interpreter.get_output_details()[0]
    interpreter.set_tensor(inp["index"],
                           np.zeros((1, SEQUENCE_LENGTH), dtype=np.int32))
    interpreter.invoke()
    sample_output = interpreter.get_tensor(out["index"])
    assert sample_output.shape == (1, len(LABELS))
    print("\nTFLite verification successful:", sample_output.shape)


def main():
    print("=== FOODWISE WEIGHTED NEURAL NETWORK TRAINING ===")
    AI_DIR.mkdir(parents=True, exist_ok=True)
    texts, targets = load_data()
    train_idx, val_idx, test_idx = split_indices(targets)
    tokens, vocabulary = tokenize(texts, train_idx)
    x_train, y_train = tokens[train_idx], targets[train_idx]
    x_val, y_val = tokens[val_idx], targets[val_idx]
    x_test, y_test = tokens[test_idx], targets[test_idx]

    model = build_model(len(vocabulary), y_train)
    history = model.fit(
        x_train, y_train,
        validation_data=(x_val, y_val),
        epochs=EPOCHS,
        batch_size=BATCH_SIZE,
        verbose=1,
        callbacks=[
            keras.callbacks.EarlyStopping(
                monitor="val_loss", patience=18, restore_best_weights=True
            ),
            keras.callbacks.ReduceLROnPlateau(
                monitor="val_loss", patience=7, factor=0.5,
                min_lr=0.00001,
            ),
        ],
    )
    pd.DataFrame(history.history).to_csv(
        ML_DIR / "training_history.csv", index=False
    )

    val_probs = model.predict(x_val, verbose=0)
    threshold = choose_threshold(y_val, val_probs)
    test_probs = model.predict(x_test, verbose=0)
    metrics = evaluate(y_test, test_probs, threshold)
    save_json(ML_DIR / "training_metrics.json", metrics)
    save_json(ML_DIR / "split_indices.json", {
        "seed": SEED,
        "train": train_idx.tolist(),
        "validation": val_idx.tolist(),
        "test": test_idx.tolist(),
    })
    export_model(model, vocabulary, threshold)

    print("\nFinished! Check ml/training_metrics.json")
    if metrics["micro_f1"] < 0.50:
        print("WARNING: Model is still a prototype. Improve and test further.")
    print("Synthetic-data test scores are NOT real-world accuracy estimates.")


if __name__ == "__main__":
    main()