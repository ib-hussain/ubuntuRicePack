import socket
import time

node = socket.gethostname()
print(f"{node}: Starting at {time.strftime('%H:%M:%S')}")
time.sleep(3)
print(f"{node}: Finishing at {time.strftime('%H:%M:%S')}")
#this was made by deepseek
