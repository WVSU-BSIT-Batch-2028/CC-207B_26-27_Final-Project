
from pathlib import Path
import pandas as pd

BASE_DIR = Path(__file__).parent

INPUT_FILE = BASE_DIR / "training_data.csv"
OUTPUT_FILE = BASE_DIR / "training_data_clean.csv"


def main():

    print("=" * 50)
    print("FOODWISE DATASET CLEANER")
    print("=" * 50)

    df = pd.read_csv(INPUT_FILE)

    original_count = len(df)

    # Normalize text for duplicate detection
    df["_normalized"] = (
        df["text"]
        .astype(str)
        .str.strip()
        .str.casefold()
        .str.replace(r"\s+", " ", regex=True)
    )

    # Normalize labels for comparison
    df["_label_key"] = df["labels"].apply(
        lambda value: "|".join(
            sorted(
                set(
                    label.strip()
                    for label in str(value).split("|")
                    if label.strip()
                )
            )
        )
    )

    # Find identical requests with conflicting labels
    label_variations = (
        df.groupby("_normalized")["_label_key"].nunique()
    )

    conflicts = label_variations[label_variations > 1]

    print("\nConflicting duplicate requests:")

    if conflicts.empty:
        print("None found.")
    else:
        for request in conflicts.index:
            print("\nRequest:", request)

            matching = df[df["_normalized"] == request]

            print(matching[["text", "labels"]].to_string(index=False))

    # Remove duplicates only when BOTH text and labels match.
    # Conflicting label examples are preserved for review.
    clean = df.drop_duplicates(
        subset=["_normalized", "_label_key"],
        keep="first"
    ).copy()

    clean = clean.drop(
        columns=["_normalized", "_label_key"]
    )

    clean.to_csv(OUTPUT_FILE, index=False)

    print("\nCLEANING RESULTS")
    print("-" * 50)

    print("Original records:", original_count)
    print("Clean records:", len(clean))
    print("Removed duplicates:", original_count - len(clean))
    print("Remaining unique requests:", clean["text"].nunique())

    print("\nSaved to:", OUTPUT_FILE)

    print("\nCleaning completed successfully.")


if __name__ == "__main__":
    main()