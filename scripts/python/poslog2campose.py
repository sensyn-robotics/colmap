import pandas as pd
import os

script_path = os.path.dirname(os.path.realpath(__file__))

df = pd.read_csv(script_path + "/../../work/poslog.csv", names=['status','camera time', 'system time', 'x', 'y', 'z', 'roll', 'pitch', 'yaw', 'xvel', 'yvel', 'zvel'
])
df = df.iloc[:,3:6]
df.insert(0,'num',[f'img{i:06}_0_0.png' for i in range(df.shape[0])])

df.iloc[:,0:].to_csv(script_path + "/../../work/campose.txt", header=False, index=False, sep=' ')
