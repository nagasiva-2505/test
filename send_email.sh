Perfect, let’s enhance the email stage so that:

✅ The send_email.sh will still send a beautiful report from GitLab SMTP.
✅ After sending the email, it cleans up all generated .txt files and temporary logs/packages from the server to save space.

Here’s how we do it:


---

📝 Enhanced Email Stage in .gitlab-ci.yml

email:
  stage: notify
  script:
    - echo "📧 Preparing to send email notification for $GROUP_NAME/$APP_NAME ..."
    - |
      # SSH into the server to fetch the report logs
      ssh $SERVER_USER@$SERVER_HOST bash -c "'
        if [[ ! -d \"$LOGS_PATH/pipeline_logs/$TIMESTAMP\" ]]; then
          echo \"⚠️  No logs found for this pipeline run. Skipping email.\"
          exit 0
        fi

        # Compress the logs folder (optional)
        tar -czf \"$LOGS_PATH/pipeline_logs/${TIMESTAMP}_logs.tar.gz\" -C \"$LOGS_PATH/pipeline_logs\" \"$TIMESTAMP\"
      '"

      # Copy logs from server to runner for email processing
      scp $SERVER_USER@$SERVER_HOST:$LOGS_PATH/pipeline_logs/${TIMESTAMP}_logs.tar.gz .

      # Extract logs locally
      tar -xzf ${TIMESTAMP}_logs.tar.gz

      # Send email using GitLab SMTP
      bash $SCRIPTS_PATH/send_email.sh \
        "./$TIMESTAMP" \
        "$EMAIL_RECIPIENT" \
        "$CI_PIPELINE_URL"

      echo "✅ Email sent successfully."

      # Clean up local extracted files and package
      rm -rf "./$TIMESTAMP" "${TIMESTAMP}_logs.tar.gz"

      # Clean up logs on server to save space
      ssh $SERVER_USER@$SERVER_HOST bash -c "'
        echo \"🧹 Cleaning up old logs and temporary files on server...\"
        rm -rf \"$LOGS_PATH/pipeline_logs/$TIMESTAMP\"
        echo \"✅ Cleanup completed on server.\"
      '"
  rules:
    - if: '$CI_PIPELINE_SOURCE == "pipeline"'


---

🛠 Updated send_email.sh

#!/bin/bash

# Arguments
CURRENT_LOG_PATH=$1
EMAIL_RECIPIENT=$2
CI_PIPELINE_URL=$3

# Build HTML Email
EMAIL_BODY="<html><body>"
EMAIL_BODY+="<h2 style='color:#2E86C1;'>🚀 SAS Viya CI/CD Pipeline Report</h2>"
EMAIL_BODY+="<p>Pipeline: <a href='$CI_PIPELINE_URL'>$CI_PIPELINE_URL</a></p>"

# Table of Summary
EMAIL_BODY+="<table border='1' cellpadding='8' cellspacing='0' style='border-collapse:collapse;font-family:Arial;'>"
EMAIL_BODY+="<tr style='background-color:#f2f2f2;'>
               <th>Stage</th>
               <th style='color:green;'>✅ Passed</th>
               <th style='color:red;'>❌ Failed</th>
               <th>Total</th>
             </tr>"

# Loop through stages
for stage in lint convert run test deploy; do
    pass_file="$CURRENT_LOG_PATH/${stage}_passed.txt"
    fail_file="$CURRENT_LOG_PATH/${stage}_failed.txt"

    pass_count=$( [ -f "$pass_file" ] && grep -c . "$pass_file" || echo 0 )
    fail_count=$( [ -f "$fail_file" ] && grep -c . "$fail_file" || echo 0 )
    total_count=$((pass_count + fail_count))

    EMAIL_BODY+="<tr>
                    <td><b>${stage^}</b></td>
                    <td>$pass_count</td>
                    <td>$fail_count</td>
                    <td>$total_count</td>
                 </tr>"
done

EMAIL_BODY+="</table><br>"

# Detailed job list
for stage in lint convert run test deploy; do
    EMAIL_BODY+="<h3 style='color:#34495E;'>📂 ${stage^} Stage Details</h3>"

    pass_file="$CURRENT_LOG_PATH/${stage}_passed.txt"
    fail_file="$CURRENT_LOG_PATH/${stage}_failed.txt"

    if [ -f "$pass_file" ]; then
        EMAIL_BODY+="<p style='color:green;'><b>✅ Passed Jobs:</b></p><ul>"
        while IFS= read -r job; do
            EMAIL_BODY+="<li>$job</li>"
        done < "$pass_file"
        EMAIL_BODY+="</ul>"
    else
        EMAIL_BODY+="<p style='color:green;'>✅ No passed jobs</p>"
    fi

    if [ -f "$fail_file" ]; then
        EMAIL_BODY+="<p style='color:red;'><b>❌ Failed Jobs:</b></p><ul>"
        while IFS= read -r job; do
            EMAIL_BODY+="<li>$job</li>"
        done < "$fail_file"
        EMAIL_BODY+="</ul>"
    else
        EMAIL_BODY+="<p style='color:red;'>❌ No failed jobs</p>"
    fi
done

EMAIL_BODY+="<hr><p style='font-size:small;color:gray;'>This report was generated automatically by the SAS Viya CI/CD pipeline.</p>"
EMAIL_BODY+="</body></html>"

# Send Email via GitLab SMTP
echo "$EMAIL_BODY" | mailx -a "Content-Type: text/html" -s "📊 SAS Viya Pipeline Report" "$EMAIL_RECIPIENT"

echo "✅ Email sent to $EMAIL_RECIPIENT"


---

✅ What Changed

1. The email stage fetches logs from the server before composing the report.


2. After sending the email, all .txt and temporary log directories on the server are deleted to save storage.


3. Works with GitLab SMTP; no external email server is used.




---

Do you want me to:
✅ Combine this updated email stage and send_email.sh into the final `.gitlab-ci.yml with all stages?
✅ And simulate the HTML email preview (like in Gmail/Outlook)?
