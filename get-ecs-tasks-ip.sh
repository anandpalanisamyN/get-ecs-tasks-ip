#!/bin/bash

CLUSTER_NAME=""
PROFILE_NAME=""
FILTER_SERVICE=$1

# Create a temporary HTML file
TEMP_HTML=$(mktemp).html

# Start HTML
cat <<EOF > "$TEMP_HTML"
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>ECS Task IPs</title>
  <style>
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      background: #f8f9fa;
      color: #343a40;
      padding: 20px;
    }
    h1 {
      color: #2c3e50;
    }
    .service {
      margin-bottom: 40px;
    }
    .service h2 {
      background: #007bff;
      color: white;
      padding: 12px 16px;
      border-radius: 6px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 12px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    }
    th, td {
      padding: 12px 15px;
      text-align: left;
    }
    th {
      background: #0056b3;
      color: white;
      text-transform: uppercase;
      font-size: 14px;
      letter-spacing: 0.5px;
    }
    td {
      background: #ffffff;
    }
    tr:hover td {
      background-color: #f1f1f1;
    }
    a {
      color: #007bff;
      text-decoration: none;
      font-weight: bold;
    }
    a:hover {
      text-decoration: underline;
    }
    .footer {
      margin-top: 50px;
      font-style: italic;
      color: #666;
    }
  </style>
</head>
<body>
  <h1>📊 ECS Service Task IPs</h1>
EOF

# Get all ECS services in the cluster
SERVICE_ARNS=$(aws ecs list-services --cluster "$CLUSTER_NAME" --profile "$PROFILE_NAME" --output text --query "serviceArns[]")

# Loop through each service
for SERVICE_ARN in $SERVICE_ARNS; do
  SERVICE_NAME=$(basename "$SERVICE_ARN")

  # Filter by service name if passed
  if [[ -n "$FILTER_SERVICE" && "$SERVICE_NAME" != *"$FILTER_SERVICE"* ]]; then
    continue
  fi

  echo -e "\n📦 Checking service: $SERVICE_NAME"

  TASK_ARNS=$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --service-name "$SERVICE_NAME" --profile "$PROFILE_NAME" --query "taskArns[]" --output text)

  if [[ -z "$TASK_ARNS" ]]; then
    continue
  fi

  # Get task descriptions
  DESCRIBE_OUTPUT=$(aws ecs describe-tasks --cluster "$CLUSTER_NAME" --tasks $TASK_ARNS --profile "$PROFILE_NAME" \
    --query "tasks[].attachments[].details[?name=='privateIPv4Address'].value" --output text | tr '\t' '\n' | sort -u)

  echo "<div class='service'>" >> "$TEMP_HTML"
  echo "<h2>📦 $SERVICE_NAME</h2>" >> "$TEMP_HTML"
  echo "<table><tr><th>IP Address</th><th>Link</th></tr>" >> "$TEMP_HTML"

  while IFS= read -r IP_ADDRESS; do
    if [[ -z "$IP_ADDRESS" || ! "$IP_ADDRESS" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      continue
    fi
    echo "<tr><td>${IP_ADDRESS}</td><td><a href='http://${IP_ADDRESS}:8080' target='_blank'>Open</a></td></tr>" >> "$TEMP_HTML"
  done <<< "$DESCRIBE_OUTPUT"

  echo "</table></div>" >> "$TEMP_HTML"
done

# End HTML
cat <<EOF >> "$TEMP_HTML"
  <div class="footer">
    Report generated on $(date)
  </div>
</body>
</html>
EOF

# Open in browser
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  xdg-open "$TEMP_HTML"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  open "$TEMP_HTML"
elif [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" ]]; then
  start "$TEMP_HTML"
else
  echo "Open the following file manually: $TEMP_HTML"
fi
