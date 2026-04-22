"""
Load testing for Task Manager API.
Tests all CRUD operations with realistic traffic patterns.
Designed to trigger HPA autoscaling when user count is high enough.
"""

import random
import string
from datetime import datetime, timedelta

from locust import HttpUser, between, task


def random_title():
    adjectives = ["Important", "Urgent", "Minor", "Critical", "Optional", "Weekly", "Daily"]
    nouns = ["Review", "Deployment", "Meeting", "Report", "Update", "Cleanup", "Backup"]
    return f"{random.choice(adjectives)} {random.choice(nouns)} {''.join(random.choices(string.ascii_lowercase, k=4))}"


def random_content():
    templates = [
        "This task needs to be completed before the deadline.",
        "Follow up on the previous discussion regarding this item.",
        "Coordinate with the team to finalize the deliverables.",
        "Review and validate all changes before merging.",
        "Prepare documentation and share with stakeholders.",
    ]
    return random.choice(templates)


def random_due_date():
    days_ahead = random.randint(1, 30)
    due = datetime.now() + timedelta(days=days_ahead)
    return due.strftime("%Y-%m-%d")


class TaskManagerUser(HttpUser):
    """
    Simulates a user interacting with the Task Manager API.
    Weights reflect realistic usage: reads are far more frequent than writes.
    """

    wait_time = between(1, 3)
    token = "dev-token-change-in-production"
    created_task_ids = []

    def on_start(self):
        """Seed a few tasks on user start so read/update/delete have targets."""
        for _ in range(3):
            self._create_task()

    def _auth_headers(self):
        return {"Authorization": f"Bearer {self.token}"}

    def _create_task(self):
        payload = {
            "title": random_title(),
            "content": random_content(),
            "due_date": random_due_date(),
        }
        with self.client.post(
            "/tasks",
            json=payload,
            headers=self._auth_headers(),
            catch_response=True,
        ) as resp:
            if resp.status_code == 201:
                try:
                    data = resp.json()
                    task_id = data.get("id") or data.get("_id") or data.get("taskId")
                    if task_id:
                        self.created_task_ids.append(str(task_id))
                    resp.success()
                except Exception:
                    resp.success()
            elif resp.status_code == 200:
                try:
                    data = resp.json()
                    task_id = data.get("id") or data.get("_id") or data.get("taskId")
                    if task_id:
                        self.created_task_ids.append(str(task_id))
                except Exception:
                    pass
                resp.success()
            else:
                resp.failure(f"Create task failed: {resp.status_code}")

    def _pick_task_id(self):
        if self.created_task_ids:
            return random.choice(self.created_task_ids)
        return None

    # ------------------------------------------------------------------ #
    # Health / readiness -- lightweight, high frequency
    # ------------------------------------------------------------------ #

    @task(5)
    def health_check(self):
        self.client.get("/health")

    @task(3)
    def readiness_check(self):
        self.client.get("/ready")

    @task(2)
    def metrics(self):
        self.client.get("/metrics")

    # ------------------------------------------------------------------ #
    # Read operations -- the bulk of real traffic
    # ------------------------------------------------------------------ #

    @task(10)
    def list_tasks(self):
        self.client.get("/tasks", headers=self._auth_headers())

    @task(8)
    def get_single_task(self):
        task_id = self._pick_task_id()
        if task_id:
            self.client.get(
                f"/tasks/{task_id}",
                headers=self._auth_headers(),
                name="/tasks/:id",
            )
        else:
            self.client.get("/tasks", headers=self._auth_headers())

    # ------------------------------------------------------------------ #
    # Write operations -- less frequent
    # ------------------------------------------------------------------ #

    @task(4)
    def create_task(self):
        self._create_task()

    @task(3)
    def update_task(self):
        task_id = self._pick_task_id()
        if not task_id:
            return
        payload = {
            "title": random_title(),
            "content": random_content(),
            "due_date": random_due_date(),
        }
        self.client.put(
            f"/tasks/{task_id}",
            json=payload,
            headers=self._auth_headers(),
            name="/tasks/:id",
        )

    @task(1)
    def delete_task(self):
        task_id = self._pick_task_id()
        if not task_id:
            return
        with self.client.delete(
            f"/tasks/{task_id}",
            headers=self._auth_headers(),
            name="/tasks/:id",
            catch_response=True,
        ) as resp:
            if resp.status_code in (200, 204, 404):
                resp.success()
                if task_id in self.created_task_ids:
                    self.created_task_ids.remove(task_id)
            else:
                resp.failure(f"Delete failed: {resp.status_code}")
