set -e

echo "========== Nexus IQ Policy Result =========="

echo "NEXUS_IQ_RESULTS_FILE=${NEXUS_IQ_RESULTS_FILE}"

if [ -z "${NEXUS_IQ_RESULTS_FILE}" ]; then
  echo "ERROR: NEXUS_IQ_RESULTS_FILE is empty"
  exit 1
fi

if [ ! -f "${NEXUS_IQ_RESULTS_FILE}" ]; then
  echo "ERROR: Nexus IQ result file not found: ${NEXUS_IQ_RESULTS_FILE}"
  echo "Files under /harness:"
  ls -la /harness || true
  exit 1
fi

echo "Raw Nexus IQ JSON:"
cat "${NEXUS_IQ_RESULTS_FILE}"

POLICY_ACTION=$(sed -n 's/.*"policyAction"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${NEXUS_IQ_RESULTS_FILE}" | head -1)

REPORT_URL=$(sed -n 's/.*"reportHtmlUrl"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${NEXUS_IQ_RESULTS_FILE}" | head -1)

if [ -z "${POLICY_ACTION}" ]; then
  echo "WARNING: policyAction not found in Nexus IQ JSON"
  POLICY_ACTION="UNKNOWN"
fi

if [ -z "${REPORT_URL}" ]; then
  echo "WARNING: reportHtmlUrl not found in Nexus IQ JSON"
  REPORT_URL="NA"
fi

echo "Parsed Nexus IQ values:"
echo "policy_action=${POLICY_ACTION}"
echo "report_url=${REPORT_URL}"
echo "report_file=${NEXUS_IQ_RESULTS_FILE}"

cat > nexus_policy_input.json <<EOF
{
  "tool": "nexus_iq",
  "policy_action": "${POLICY_ACTION}",
  "report_url": "${REPORT_URL}",
  "report_file": "${NEXUS_IQ_RESULTS_FILE}"
}
EOF

echo "Policy input JSON:"
cat nexus_policy_input.json

export policy_action="${POLICY_ACTION}"
export report_url="${REPORT_URL}"
export report_file="${NEXUS_IQ_RESULTS_FILE}"

echo "Exported Harness output variables:"
echo "policy_action=${policy_action}"
echo "report_url=${report_url}"
echo "report_file=${report_file}"

echo "========== End Nexus IQ Policy Result =========="

policy_action
report_url
report_file

===
{
  "tool": "nexus_iq",
  "policy_action": "<+steps.get_nexus_policy_result.output.outputVariables.policy_action>",
  "report_url": "<+steps.get_nexus_policy_result.output.outputVariables.report_url>",
  "report_file": "<+steps.get_nexus_policy_result.output.outputVariables.report_file>"
}

==
package nexus

deny[msg] {
  input.tool == "nexus_iq"
  input.policy_action == "Failure"
  msg := sprintf("Nexus IQ policy failed. Report: %s", [input.report_url])
}

===
package nexus

deny[msg] {
  input.tool == "nexus_iq"
  input.policy_action == "Failure"
  msg := sprintf("Nexus IQ policy failed. Report: %s", [input.report_url])
}

deny[msg] {
  input.tool == "nexus_iq"
  input.policy_action == "Warning"
  msg := sprintf("Nexus IQ policy has warning. Report: %s", [input.report_url])
}


==

