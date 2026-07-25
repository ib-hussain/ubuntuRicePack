#!/usr/bin/env python3
import pickle
import socket
import threading
import time
import queue
import os
import subprocess
from pathlib import Path

class TaskQueueServer:
    def __init__(self, host='0.0.0.0', port=8888):
        self.host = host
        self.port = port
        self.tasks = queue.Queue()
        self.results = {}
        self.lock = threading.Lock()
        
    def add_task(self, command):
        """Add a task to the queue"""
        task_id = int(time.time() * 1000000)
        self.tasks.put((task_id, command))
        print(f"[Server] Added task {task_id}: {command}")
        return task_id
    
    def handle_client(self, conn, addr):
        """Handle worker connection"""
        try:
            data = conn.recv(4096).decode()
            if data == "GET_WORK":
                if not self.tasks.empty():
                    task_id, command = self.tasks.get()
                    conn.send(pickle.dumps(('TASK', task_id, command)))
                    print(f"[Server] Assigned task {task_id} to {addr}")
                else:
                    conn.send(pickle.dumps(('NO_WORK',)))
            
            elif data.startswith("DONE:"):
                task_id = int(data.split(":")[1])
                with self.lock:
                    self.results[task_id] = "completed"
                print(f"[Server] Task {task_id} completed by {addr}")
                conn.send(pickle.dumps(('ACK',)))
                
        except Exception as e:
            print(f"[Server] Error: {e}")
        finally:
            conn.close()
    
    def run(self):
        """Start the server"""
        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind((self.host, self.port))
        server.listen(10)
        print(f"[Server] Listening on {self.host}:{self.port}")
        
        while True:
            conn, addr = server.accept()
            thread = threading.Thread(target=self.handle_client, args=(conn, addr))
            thread.daemon = True
            thread.start()

if __name__ == "__main__":
    server = TaskQueueServer()
    
    # Start server in background thread
    import threading
    server_thread = threading.Thread(target=server.run)
    server_thread.daemon = True
    server_thread.start()
    
    # Command line interface for adding tasks
    print("Task Queue Server Started")
    print("Commands:")
    print("  add <command> - Add task")
    print("  list - Show pending tasks")
    print("  quit - Stop server")
    
    while True:
        cmd = input("> ").strip()
        if cmd.startswith("add "):
            command = cmd[4:]
            server.add_task(command)
        elif cmd == "list":
            print(f"Pending tasks: {server.tasks.qsize()}")
        elif cmd == "quit":
            break
#this is made by deepseek
