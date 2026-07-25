#!/usr/bin/env python3
import socket
import pickle
import subprocess
import time
import sys
import os
from pathlib import Path

class WorkerClient:
    def __init__(self, server_host='10.10.10.1', server_port=8888, worker_name=None):
        self.server_host = server_host
        self.server_port = server_port
        self.worker_name = worker_name or socket.gethostname()
        # Find the venv python
        home = Path.home()
        self.venv_python = home / "cluster-work/venv3.12.7/bin/python3"
        if not self.venv_python.exists():
            print(f"[{self.worker_name}] Warning: venv not found at {self.venv_python}")
            self.venv_python = "python3"
    
    def get_work(self):
        """Request work from server"""
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.connect((self.server_host, self.server_port))
            sock.send(b"GET_WORK")
            data = sock.recv(4096)
            result = pickle.loads(data)
            sock.close()
            return result
        except:
            return ('NO_WORK',)
    
    def report_complete(self, task_id):
        """Report task completion"""
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.connect((self.server_host, self.server_port))
            sock.send(f"DONE:{task_id}".encode())
            sock.close()
        except:
            pass
    
    def run_task(self, command):
        """Execute a task"""
        print(f"[{self.worker_name}] Running: {command}")
        try:
            # Replace python/python3 with venv python
            if command.startswith("python ") or command.startswith("python3 "):
                command = command.replace("python ", f"{self.venv_python} ")
                command = command.replace("python3 ", f"{self.venv_python} ")
            
            result = subprocess.run(command, shell=True, capture_output=True, text=True, timeout=3600)
            if result.stdout:
                print(f"[{self.worker_name}] Output: {result.stdout}")
            if result.stderr:
                print(f"[{self.worker_name}] Error: {result.stderr}")
            return result.returncode == 0
        except Exception as e:
            print(f"[{self.worker_name}] Task failed: {e}")
            return False
    
    def run(self):
        """Main worker loop"""
        print(f"[{self.worker_name}] Worker started, using python: {self.venv_python}")
        
        while True:
            result = self.get_work()
            if result[0] == 'TASK':
                _, task_id, command = result
                success = self.run_task(command)
                self.report_complete(task_id)
                print(f"[{self.worker_name}] Completed task {task_id}")
            elif result[0] == 'NO_WORK':
                time.sleep(2)  # No work, wait
            else:
                time.sleep(1)

if __name__ == "__main__":
    name = sys.argv[1] if len(sys.argv) > 1 else None
    worker = WorkerClient(worker_name=name)
    worker.run()
#this is made by deepseek
