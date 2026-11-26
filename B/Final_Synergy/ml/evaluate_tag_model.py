import csv
import random
from collections import Counter
from pathlib import Path

import mediapipe as mp


LABELS = (
    "Beta Testers", "Product Feedback", "User Research",
    "Technical Development", "none",
)
DEMOS = (
    ("We can review your app and give design feedback", "Product Feedback"),
    ("We need students to try our signup", "Beta Testers"),
)


def predict(classifier, sentence):
    categories = classifier.classify(sentence).classifications[0].categories
    best = max(categories, key=lambda category: category.score)
    return best.category_name, best.score


def main():
    directory = Path(__file__).resolve().parent
    with (directory / "tag_examples.csv").open(encoding="utf-8", newline="") as source:
        rows = list(csv.DictReader(source))

    # Recreate the original validation split from the CSV in its training order.
    random.Random(42).shuffle(rows)
    validation = rows[int(len(rows) * 0.8):]

    with mp.tasks.text.TextClassifier.create_from_model_path(
        str(directory / "tag_model.tflite")
    ) as classifier:
        results = [
            (row["text"], row["label"], *predict(classifier, row["text"]))
            for row in validation
        ]
        demos = [
            (sentence, expected, *predict(classifier, sentence))
            for sentence, expected in DEMOS
        ]

    # Rows are expected labels. Columns are top-scoring predicted labels.
    counts = Counter((expected, predicted) for _, expected, predicted, _ in results)
    width = max(map(len, LABELS))
    print(f"Validation confusion table ({len(results)} sentences)")
    print(f"{'Expected / predicted':<{width}} " + " ".join(f"{label:>{width}}" for label in LABELS))
    for expected in LABELS:
        cells = " ".join(f"{counts[expected, predicted]:>{width}}" for predicted in LABELS)
        print(f"{expected:<{width}} {cells}")

    print("\nWrong predictions")
    for sentence, expected, predicted, score in results:
        if expected != predicted:
            print(f"{sentence} | expected={expected} | predicted={predicted} | score={score:.3f}")

    low_scores = [result for result in results if result[3] < 0.6]
    low_correct = sum(expected == predicted for _, expected, predicted, _ in low_scores)
    print(f"\nScores below 0.6: {len(low_scores)}/{len(results)} ({low_correct} correct)")

    print("\nDemo sentences")
    for sentence, expected, predicted, score in demos:
        print(f"{sentence} | expected={expected} | predicted={predicted} | score={score:.3f}")


if __name__ == "__main__":
    main()
