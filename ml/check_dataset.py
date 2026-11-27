from pathlib import Path
from collections import Counter

import pandas as pd

# Dataset location
DATA_PATH = Path(__file__).with_name("training_data.csv")

# All supported FoodWise labels
ALLOWED_LABELS = {
    "meal_breakfast",
    "meal_lunch",
    "meal_dinner",
    "meal_snack",

    "pref_chicken",
    "pref_fish",
    "pref_vegetables",
    "pref_rice",
    "pref_noodles",
    "pref_egg",
    "pref_fruit",

    "avoid_spicy",
    "avoid_dairy",
    "avoid_peanuts",
    "avoid_seafood",
    "avoid_egg",
    "avoid_gluten",

    "diet_vegetarian",
    "diet_vegan",
    "budget_friendly",
    "filling",

    "allergy_peanuts",
    "allergy_dairy",
    "allergy_seafood",
    "allergy_egg",
    "restriction_gluten",
    "allergy_gluten",
}

MIN_LABEL_EXAMPLES = 10


def main():
    print("=" * 55)
    print("FOODWISE AI DATASET QUALITY CHECKER")
    print("=" * 55)

    if not DATA_PATH.exists():
        print("ERROR: training_data.csv not found.")
        return

    df = pd.read_csv(DATA_PATH)

    # Check required columns
    required_columns = {"text", "labels"}

    if not required_columns.issubset(df.columns):
        print("ERROR: Required columns are text and labels.")
        return

    print("\n1. BASIC INFORMATION")
    print("-" * 55)

    print("Total records:", len(df))
    print("Columns:", list(df.columns))

    # Check missing values
    print("\n2. MISSING VALUES")
    print("-" * 55)

    print(df[["text", "labels"]].isna().sum())

    # Clean text for duplicate detection
    df["_normalized"] = (
        df["text"]
        .fillna("")
        .astype(str)
        .str.strip()
        .str.casefold()
        .str.replace(r"\s+", " ", regex=True)
    )

    # Parse labels
    def parse_labels(value):
        if pd.isna(value):
            return []

        return [
            label.strip()
            for label in str(value).split("|")
            if label.strip()
        ]

    df["_labels"] = df["labels"].apply(parse_labels)

    # Check empty records
    print("\n3. EMPTY RECORDS")
    print("-" * 55)

    empty_rows = df[
        (df["_normalized"] == "") |
        (df["_labels"].apply(len) == 0)
    ]

    print("Empty records:", len(empty_rows))

    # Check invalid labels
    print("\n4. INVALID LABELS")
    print("-" * 55)

    found_labels = set(
        label
        for labels in df["_labels"]
        for label in labels
    )

    invalid_labels = found_labels - ALLOWED_LABELS

    if invalid_labels:
        print("Invalid labels:", sorted(invalid_labels))
    else:
        print("All labels are valid.")

    # Check duplicate requests
    print("\n5. DUPLICATE REQUESTS")
    print("-" * 55)

    duplicates = df[
        df["_normalized"].duplicated(keep=False)
    ].sort_values("_normalized")

    if duplicates.empty:
        print("No duplicate requests found.")
    else:
        for text, group in duplicates.groupby("_normalized"):
            print("\nRequest:", text)

            for _, row in group.iterrows():
                print("Labels:", row["_labels"])

    # Check label distribution
    print("\n6. LABEL DISTRIBUTION")
    print("-" * 55)

    label_counts = Counter(
        label
        for labels in df["_labels"]
        for label in labels
    )

    for label in sorted(ALLOWED_LABELS):
        count = label_counts[label]
        status = (
            "NEEDS MORE DATA"
            if count < MIN_LABEL_EXAMPLES
            else "OK"
        )

        print(f"{label:25} {count:4}  {status}")

    # Check missing categories
    missing_labels = ALLOWED_LABELS - found_labels

    print("\n7. MISSING LABELS")
    print("-" * 55)

    if missing_labels:
        print(sorted(missing_labels))
    else:
        print("No missing labels.")

    # Final summary
    print("\n8. FINAL SUMMARY")
    print("-" * 55)

    print("Total records:", len(df))
    print("Unique requests:", df["_normalized"].nunique())
    print("Duplicate excess records:",
          len(df) - df["_normalized"].nunique())
    print("Unique labels:", len(found_labels))
    print("Invalid labels:", len(invalid_labels))
    print("Underrepresented labels:", sum(
        label_counts[label] < MIN_LABEL_EXAMPLES
        for label in ALLOWED_LABELS
    ))

    print("\nDataset inspection completed.")


if __name__ == "__main__":
    main()