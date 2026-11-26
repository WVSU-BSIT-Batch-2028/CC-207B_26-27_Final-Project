"""Train the tag classifier used by the profile screen's "Suggest tags" button.

Reconstructed after the fact: the script that produced the committed
tag_model.tflite was not saved. This one uses the same split that
evaluate_tag_model.py assumes (shuffle with random.Random(42), first 80%
train, last 20% validation) and MediaPipe Model Maker's small
average-word-embedding classifier, which matches the ~100 KB model size.
Retraining may give slightly different scores from the committed model.

Setup:  pip install mediapipe-model-maker
Run:    python ml/train_tag_model.py  (from B/Final_Synergy)
Then copy ml/tag_model.tflite to web/tag_model/tag_model.tflite
and check it with python ml/evaluate_tag_model.py.
"""

import csv
import random
import shutil
import tempfile
from pathlib import Path

from mediapipe_model_maker import text_classifier


def write_csv(path, rows):
    with path.open("w", encoding="utf-8", newline="") as target:
        writer = csv.DictWriter(target, fieldnames=["text", "label"])
        writer.writeheader()
        writer.writerows(rows)


def main():
    directory = Path(__file__).resolve().parent
    with (directory / "tag_examples.csv").open(encoding="utf-8", newline="") as source:
        rows = list(csv.DictReader(source))

    # Same split as evaluate_tag_model.py.
    random.Random(42).shuffle(rows)
    cut = int(len(rows) * 0.8)

    csv_params = text_classifier.CSVParams(text_column="text", label_column="label")
    with tempfile.TemporaryDirectory() as work:
        work = Path(work)
        write_csv(work / "train.csv", rows[:cut])
        write_csv(work / "validation.csv", rows[cut:])
        train = text_classifier.Dataset.from_csv(str(work / "train.csv"), csv_params)
        validation = text_classifier.Dataset.from_csv(str(work / "validation.csv"), csv_params)

        options = text_classifier.TextClassifierOptions(
            supported_model=text_classifier.SupportedModels.AVERAGE_WORD_EMBEDDING_CLASSIFIER,
            hparams=text_classifier.AverageWordEmbeddingHParams(
                epochs=10,
                batch_size=32,
                learning_rate=0,  # 0 = Model Maker's default
                export_dir=str(work / "export"),
            ),
        )
        model = text_classifier.TextClassifier.create(train, validation, options)

        loss, accuracy = model.evaluate(validation)
        print(f"Validation loss {loss:.3f}, accuracy {accuracy:.3f}")

        model.export_model("tag_model.tflite")
        shutil.copy(work / "export" / "tag_model.tflite", directory / "tag_model.tflite")
        print(f"Wrote {directory / 'tag_model.tflite'}")


if __name__ == "__main__":
    main()
