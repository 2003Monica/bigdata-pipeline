import pandas as pd

df = pd.read_csv("data/data.csv")

print("Dataset Statistics")
print("Total rows:", len(df))
print("Sum:", df["value"].sum())
print("Average:", df["value"].mean())
print("Minimum:", df["value"].min())
print("Maximum:", df["value"].max())