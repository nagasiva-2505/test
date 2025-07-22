#!/bin/bash

# ------------------------------
# Inputs from pipeline
# ------------------------------
LOGS_PATH=$1                  # Path to logs directory
CURRENT_LOG_PATH=$2           # Path to current pipeline run's log folder
EMAIL_RECIPIENT=$3            # Email recipient address
CI_PIPELINE_URL=$4            # GitLab pipeline URL

# ------------------------------
# Start building the HTML email
# ------------------------------
EMAIL_BODY="<html><body>"
EMAIL_BODY+="<h2 style='color:#2E86C1;'>🚀 SAS Viya CI/CD Pipeline Report</h2>"
EMAIL_BODY+="<p>Pipeline: <a href='$CI_PIPELINE_URL'>$CI_PIPELINE_URL</a></p>"

# ------------------------------
# Summary Table
# ------------------------------
EMAIL_BODY+="<table border='1' cellpadding='8' cellspacing='0' style='border-collapse:collapse;font-family:Arial;'>"
EMAIL_BODY+="<tr style='background-color:#f2f2f2;'>
              <th>Stage</th>
              <th style='color:green;'>✅ Passed</th>
              <th style='color:red;'>❌ Failed</th>
              <th style='color:gray;'>⚠️ Skipped</th>
              <th>Total</th>
            </tr>"

for stage in lint convert run test deploy; do
    pass_file="$CURRENT_LOG_PATH/${stage}_passed.txt"
    fail_file="$CURRENT_LOG_PATH/${stage}_failed.txt"

    if [ -f "$pass_file" ] || [ -f "$fail_file" ]; then
        pass_count=$( [ -f "$pass_file" ] && grep -c . "$pass_file" || echo 0 )
        fail_count=$( [ -f "$fail_file" ] && grep -c . "$fail_file" || echo 0 )
        total_count=$((pass_count + fail_count))
        skipped="-"  # Not skipped
    else
        pass_count="-"
        fail_count="-"
        skipped="⚠️"
        total_count="-"
    fi

    EMAIL_BODY+="<tr>
                    <td><b>${stage^}</b></td>
                    <td>$pass_count</td>
                    <td>$fail_count</td>
                    <td>$skipped</td>
                    <td>$total_count</td>
                 </tr>"
done

EMAIL_BODY+="</table><br>"

# ------------------------------
# Stage Details
# ------------------------------
for stage in lint convert run test deploy; do
    EMAIL_BODY+="<h3 style='color:#34495E;'>📂 ${stage^} Stage Details</h3>"

    pass_file="$CURRENT_LOG_PATH/${stage}_passed.txt"
    fail_file="$CURRENT_LOG_PATH/${stage}_failed.txt"

    # Passed Jobs
    if [ -f "$pass_file" ] && [ -s "$pass_file" ]; then
        EMAIL_BODY+="<p style='color:green;'><b>✅ Passed Jobs:</b></p><ul>"
        while IFS= read -r job; do
            EMAIL_BODY+="<li>$job</li>"
        done < "$pass_file"
        EMAIL_BODY+="</ul>"
    else
        EMAIL_BODY+="<p style='color:green;'>✅ No passed jobs</p>"
    fi

    # Failed Jobs
    if [ -f "$fail_file" ] && [ -s "$fail_file" ]; then
        EMAIL_BODY+="<p style='color:red;'><b>❌ Failed Jobs:</b></p><ul>"
        while IFS= read -r job; do
            # If failure reason is included in the text file (e.g., job_name: reason)
            if [[ "$job" == *":"* ]]; then
                job_name=$(echo "$job" | cut -d':' -f1)
                reason=$(echo "$job" | cut -d':' -f2-)
                EMAIL_BODY+="<li><b>$job_name</b> - <i>$reason</i></li>"
            else
                EMAIL_BODY+="<li>$job</li>"
            fi
        done < "$fail_file"
        EMAIL_BODY+="</ul>"
    else
        EMAIL_BODY+="<p style='color:red;'>❌ No failed jobs</p>"
    fi
done

# ------------------------------
# Footer
# ------------------------------
EMAIL_BODY+="<hr><p style='font-size:small;color:gray;'>This report was generated automatically by the SAS Viya CI/CD pipeline.</p>"
EMAIL_BODY+="</body></html>"

# ------------------------------
# Send email
# ------------------------------
echo "$EMAIL_BODY" | mailx -a "Content-Type: text/html" -s "📊 SAS Viya Pipeline Report" "$EMAIL_RECIPIENT"

echo "✅ Email sent to $EMAIL_RECIPIENT"
