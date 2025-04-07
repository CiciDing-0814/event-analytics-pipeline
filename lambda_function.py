import base64
import json

def lambda_handler(event, context):
    for record in event['Records']:
        payload = json.loads(base64.b64decode(record['kinesis']['data']).decode('utf-8'))
        user = payload.get("user_id", "unknown")
        if payload.get("event_type") == "failed_login":
            print(f"⚠️ Potential attack from user: {user}")
