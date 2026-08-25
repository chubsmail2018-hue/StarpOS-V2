import time

abc = 0


def my_function(up):
  global abc
  abc += 1


# Loop until abc reaches 100 with a 0.25-second delay
while abc < 100:
  my_function(True)
  print(abc)
  time.sleep(0.25)  # Pauses execution for 0.25 seconds