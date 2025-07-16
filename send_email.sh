#!/bin/bash

# Variables from pipeline
LOGS_PATH=$1
CURRENT_LOG_PATH=$2
EMAIL_RECIPIENT=$3
CI_PIPELINE_URL=$4

# Build HTML email
EMAIL_BODY="<html><body>"
EMAIL_BODY+="<h2 style='color:#2E86C1;'>🚀 SAS Viya CI/CD Pipeline Report</h2>"
EMAIL_BODY+="<p>Pipeline: <a href='$CI_PIPELINE_URL'>$CI_PIPELINE_URL</a></p>"

# Table Header
EMAIL_BODY+="<table border='1' cellpadding='8' cellspacing='0' style='border-collapse:collapse;font-family:Arial;'>"
EMAIL_BODY+="<tr style='background-color:#f2f2f2;'>
              <th>Stage</th>
              <th style='color:green;'>✅ Passed</th>
              <th style='color:red;'>❌ Failed</th>
              <th>Total</th>
            </tr>"

# Stages
for stage in lint convert run test deploy; do
    pass_file="$CURRENT_LOG_PATH/${stage}_passed.txt"
    fail_file="$CURRENT_LOG_PATH/${stage}_failed.txt"

    # Read counts
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

# Show detailed lists for each stage
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

# Send email
echo "$EMAIL_BODY" | mailx -a "Content-Type: text/html" -s "📊 SAS Viya Pipeline Report" "$EMAIL_RECIPIENT"

echo "✅ Email sent to $EMAIL_RECIPIENT"
