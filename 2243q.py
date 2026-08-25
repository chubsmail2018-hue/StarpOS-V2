import sys
import random
import time

names = ["Alice", "Bob", "Charlie", "Diana", "Evan", "Fiona"]
a = 0

while a < 100:
    a += 1
    random_name = random.choice(names)
    
    # sys.stdout.write + flush is the most aggressive real-time output method
    sys.stdout.write(f"{a}: {random_name}\n")
    sys.stdout.flush()
    
    time.sleep(0.7)