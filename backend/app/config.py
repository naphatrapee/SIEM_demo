import os

DATABASE_URL = os.environ["DATABASE_URL"]
JWT_SECRET = os.environ["JWT_SECRET"]
RETENTION_DAYS = int(os.getenv("RETENTION_DAYS", "7"))
ALERT_WEBHOOK_URL = os.getenv("ALERT_WEBHOOK_URL", "")
