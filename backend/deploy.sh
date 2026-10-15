#!/usr/bin/env bash
# Creates/updates the sign-in backend for the Client Issues and Change Log tabs.
#   - DynamoDB table core-docs-content (section + id)
#   - IAM role core-docs-data-role (read the table, invoke quality-dashboard-verify, logs)
#   - Lambda core-docs-data + public Function URL (CORS: GitHub Pages site + localhost)
# Sign-in reuses quality-dashboard-login / quality-dashboard-users (no new user store).
#
#   AWS_PROFILE=asad bash backend/deploy.sh
set -euo pipefail
REGION=eu-west-2
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
TABLE=core-docs-content
ROLE=core-docs-data-role
FN=core-docs-data
VERIFY_FN=quality-dashboard-verify
DIR="$(cd "$(dirname "$0")" && pwd)"

echo "== table"
aws dynamodb describe-table --table-name $TABLE --region $REGION >/dev/null 2>&1 || {
  aws dynamodb create-table --table-name $TABLE --region $REGION --billing-mode PAY_PER_REQUEST \
    --attribute-definitions AttributeName=section,AttributeType=S AttributeName=id,AttributeType=S \
    --key-schema AttributeName=section,KeyType=HASH AttributeName=id,KeyType=RANGE >/dev/null
  aws dynamodb wait table-exists --table-name $TABLE --region $REGION; }

echo "== role"
aws iam get-role --role-name $ROLE >/dev/null 2>&1 || {
  aws iam create-role --role-name $ROLE --assume-role-policy-document \
    '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' >/dev/null
  sleep 10; }
aws iam put-role-policy --role-name $ROLE --policy-name core-docs-data --policy-document "{
 \"Version\":\"2012-10-17\",\"Statement\":[
  {\"Effect\":\"Allow\",\"Action\":[\"dynamodb:Query\"],\"Resource\":\"arn:aws:dynamodb:$REGION:$ACCOUNT:table/$TABLE\"},
  {\"Effect\":\"Allow\",\"Action\":[\"lambda:InvokeFunction\"],\"Resource\":\"arn:aws:lambda:$REGION:$ACCOUNT:function:$VERIFY_FN\"},
  {\"Effect\":\"Allow\",\"Action\":[\"logs:CreateLogGroup\",\"logs:CreateLogStream\",\"logs:PutLogEvents\"],\"Resource\":\"arn:aws:logs:$REGION:$ACCOUNT:*\"}]}"

echo "== lambda"
TMP=$(mktemp -d); cp "$DIR/core_docs_data.py" "$TMP/"; (cd "$TMP" && zip -q fn.zip core_docs_data.py)
if aws lambda get-function --function-name $FN --region $REGION >/dev/null 2>&1; then
  aws lambda update-function-code --function-name $FN --region $REGION --zip-file "fileb://$TMP/fn.zip" >/dev/null
else
  aws lambda create-function --function-name $FN --region $REGION --runtime python3.12 \
    --role "arn:aws:iam::$ACCOUNT:role/$ROLE" --handler core_docs_data.handler --timeout 15 --memory-size 256 \
    --environment "Variables={CONTENT_TABLE=$TABLE,VERIFY_FN=$VERIFY_FN}" \
    --zip-file "fileb://$TMP/fn.zip" >/dev/null
  aws lambda wait function-active --function-name $FN --region $REGION
fi

echo "== function url"
CORS='{"AllowOrigins":["https://asad-ikram-mc.github.io","http://localhost:8765"],"AllowMethods":["POST"],"AllowHeaders":["content-type"],"MaxAge":3600}'
if aws lambda get-function-url-config --function-name $FN --region $REGION >/dev/null 2>&1; then
  aws lambda update-function-url-config --function-name $FN --region $REGION --cors "$CORS" >/dev/null
else
  aws lambda create-function-url-config --function-name $FN --region $REGION --auth-type NONE --cors "$CORS" >/dev/null
  aws lambda add-permission --function-name $FN --region $REGION --statement-id public-url \
    --action lambda:InvokeFunctionUrl --principal '*' --function-url-auth-type NONE >/dev/null
fi
aws lambda get-function-url-config --function-name $FN --region $REGION --query FunctionUrl --output text
