import ray
import time

# Initialize Ray cluster
ray.init(address='auto', namespace='ml_training')

@ray.remote
class Worker:
    def __init__(self, worker_id):
        self.worker_id = worker_id
        print(f"Worker {worker_id} initialized")
    
    def train_batch(self, batch_id, data_size):
        """Simulate training on a batch"""
        print(f"Worker {self.worker_id} processing batch {batch_id} with {data_size} samples")
        time.sleep(2)  # Simulate training
        return f"Worker {self.worker_id} completed batch {batch_id}"

# Create 2 workers
workers = [Worker.remote(i) for i in range(2)]

# Distribute 10 batches across workers dynamically
futures = []
for batch in range(10):
    worker = workers[batch % 2]  # Round-robin
    future = worker.train_batch.remote(batch, 100)
    futures.append(future)

# Collect results
results = ray.get(futures)
for r in results:
    print(r)

ray.shutdown()
