import os
import socket
import time

print(f"Node: {socket.gethostname()}")
print(f"PID: {os.getpid()}")
print(f"Working directory: {os.getcwd()}")
time.sleep(2)
print(f"{socket.gethostname()} finished")
