set -e

echo "========== Nexus IQ Policy Output Preparation =========="

NEXUS_IQ_RESULTS_FILE="/harness/nexus-report.json"

echo "NEXUS_IQ_RESULTS_FILE=${NEXUS_IQ_RESULTS_FILE}"

if [ ! -f "${NEXUS_IQ_RESULTS_FILE}" ]; then
  echo "ERROR: Nexus IQ result file not found"
  echo "Files in /harness:"
  ls -la /harness || true
  exit 1
fi

echo "Raw Nexus IQ report:"
cat "${NEXUS_IQ_RESULTS_FILE}"

POLICY_ACTION=$(sed -n 's/.*"policyAction"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${NEXUS_IQ_RESULTS_FILE}" | head -1)

REPORT_URL=$(sed -n 's/.*"reportHtmlUrl"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${NEXUS_IQ_RESULTS_FILE}" | head -1)

if [ -z "${POLICY_ACTION}" ]; then
  POLICY_ACTION="UNKNOWN"
fi

if [ -z "${REPORT_URL}" ]; then
  REPORT_URL="NA"
fi

echo "Parsed values:"
echo "policy_action=${POLICY_ACTION}"
echo "report_url=${REPORT_URL}"
echo "report_file=${NEXUS_IQ_RESULTS_FILE}"

echo "Policy payload for Harness PaC:"
cat <<EOF
{
  "tool": "nexus_iq",
  "policy_action": "${POLICY_ACTION}",
  "report_url": "${REPORT_URL}",
  "report_file": "${NEXUS_IQ_RESULTS_FILE}"
}
EOF

export policy_action="${POLICY_ACTION}"
export report_url="${REPORT_URL}"
export report_file="${NEXUS_IQ_RESULTS_FILE}"

echo "Exported variables:"
echo "policy_action=${policy_action}"
echo "report_url=${report_url}"
echo "report_file=${report_file}"

echo "========== End Nexus IQ Policy Output Preparation =========="


policy_action
report_url
report_file


package nexus

deny[msg] {
  some i
  input[i].name == "output"
  input[i].outcome.outputVariables.policy_action == "Failure"
  report_url := input[i].outcome.outputVariables.report_url
  msg := sprintf("Nexus IQ policy failed. Report: %s", [report_url])
}



package nexus

deny[msg] {
  some i
  input[i].name == "output"
  input[i].outcome.outputVariables.policy_action == "Failure"
  report_url := input[i].outcome.outputVariables.report_url
  msg := sprintf("Nexus IQ policy failed. Report: %s", [report_url])
}

deny[msg] {
  some i
  input[i].name == "output"
  input[i].outcome.outputVariables.policy_action == "Warning"
  report_url := input[i].outcome.outputVariables.report_url
  msg := sprintf("Nexus IQ policy warning found. Report: %s", [report_url])
}


