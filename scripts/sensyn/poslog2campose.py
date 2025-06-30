import os
import sys

import pandas as pd

if len(sys.argv) != 2:
    print("Usage: python3 poslog2campose.py <dataset_directory>")
    sys.exit(1)

dataset_dir = sys.argv[1]

# Ensure output directory exists
os.makedirs(os.path.join(dataset_dir, "work"), exist_ok=True)

df = pd.read_csv(
    os.path.join(dataset_dir, "poslog.csv"),
    names=[
        "status",
        "camera time",
        "system time",
        "x",
        "y",
        "z",
        "roll",
        "pitch",
        "yaw",
        "xvel",
        "yvel",
        "zvel",
    ],
)
df = df.iloc[:, 3:6]
df.insert(0, "num", [f"img{i:06}_0_0.png" for i in range(df.shape[0])])

df.iloc[:, 0:].to_csv(
    os.path.join(dataset_dir, "work", "campose.txt"),
    header=False,
    index=False,
    sep=" ",
)
