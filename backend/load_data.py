"""
Load Change Log / Client Issues entries into the core-docs-content table.
The data files are NOT kept in this public repo.

  AWS_PROFILE=asad python3 backend/load_data.py changelog path/to/changelog.json
  AWS_PROFILE=asad python3 backend/load_data.py client_issues path/to/client_issues.json

Each file is a JSON array, newest first (the order the page shows). The section is
replaced in full: old rows are deleted, then the new ones written.
"""
import json, sys
import boto3
from boto3.dynamodb.conditions import Key

section, path = sys.argv[1], sys.argv[2]
assert section in ("changelog", "client_issues")
rows = json.load(open(path, encoding="utf-8"))
t = boto3.resource("dynamodb", region_name="eu-west-2").Table("core-docs-content")

old, kw = [], {"KeyConditionExpression": Key("section").eq(section), "ProjectionExpression": "#s, id",
               "ExpressionAttributeNames": {"#s": "section"}}
while True:
    p = t.query(**kw); old += p["Items"]
    if "LastEvaluatedKey" not in p: break
    kw["ExclusiveStartKey"] = p["LastEvaluatedKey"]

with t.batch_writer() as w:
    for o in old:
        w.delete_item(Key={"section": section, "id": o["id"]})
with t.batch_writer() as w:
    for i, r in enumerate(rows):
        w.put_item(Item={"section": section, "id": f"{i:05d}", "d": r.get("d", ""),
                         "data": json.dumps(r, ensure_ascii=False)})
print(f"{section}: removed {len(old)}, wrote {len(rows)}")
