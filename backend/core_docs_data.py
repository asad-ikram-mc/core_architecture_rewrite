"""
core-docs-data Lambda (Function URL). Serves the Client Issues and Change Log
entries to the docs site, but only to a signed-in user.

POST {token}  ->  {changelog:[...], client_issues:[...]}   or 401.

The token comes from the existing quality-dashboard-login endpoint (same users
table, quality-dashboard-users). It is checked by invoking the existing
quality-dashboard-verify Lambda, so this function never holds the signing secret.
CORS is set on the Function URL, not here.
"""
import json, os
import boto3
from boto3.dynamodb.conditions import Key

TABLE = os.environ.get("CONTENT_TABLE", "core-docs-content")
VERIFY_FN = os.environ.get("VERIFY_FN", "quality-dashboard-verify")
SECTIONS = ("changelog", "client_issues")

ddb = boto3.resource("dynamodb").Table(TABLE)
lam = boto3.client("lambda")


def _resp(body, status=200):
    return {"statusCode": status, "headers": {"Content-Type": "application/json"},
            "body": json.dumps(body, ensure_ascii=False)}


def _verify(token):
    ev = {"requestContext": {"http": {"method": "POST"}}, "body": json.dumps({"token": token})}
    r = lam.invoke(FunctionName=VERIFY_FN, Payload=json.dumps(ev).encode())
    out = json.loads(r["Payload"].read() or b"{}")
    body = json.loads(out.get("body") or "{}")
    return body.get("username") if body.get("valid") else None


def _section(name):
    items, kw = [], {"KeyConditionExpression": Key("section").eq(name)}
    while True:
        page = ddb.query(**kw)
        items += page["Items"]
        if "LastEvaluatedKey" not in page:
            break
        kw["ExclusiveStartKey"] = page["LastEvaluatedKey"]
    items.sort(key=lambda x: x["id"])
    return [json.loads(x["data"]) for x in items]


def handler(event, context):
    method = (event.get("requestContext", {}).get("http", {}) or {}).get("method", "")
    if method == "OPTIONS":
        return _resp({"ok": True})
    try:
        token = str(json.loads(event.get("body") or "{}").get("token", ""))
    except Exception:
        return _resp({"error": "bad request"}, 400)
    user = _verify(token) if token else None
    if not user:
        return _resp({"error": "sign in required"}, 401)
    return _resp({"user": user, **{s: _section(s) for s in SECTIONS}})
