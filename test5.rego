set -e

export NEXUSIQ_JSON="$(node -e "const r=require('/harness/nexusiq.json');console.log(JSON.stringify({components:(r.components||[]).map(c=>({name:c.displayName||c.packageUrl||'unknown',issues:(c.securityData&&c.securityData.securityIssues)||[]}))}))")"

echo "Nexus IQ payload prepared"
echo "NEXUSIQ_JSON length=${#NEXUSIQ_JSON}"


===================


package pipeline

threshold := 8

payload := json.unmarshal(input[0].outcome.outputVariables["NEXUSIQ_JSON"])

components := object.get(payload, "components", [])

high_cves := [finding |
  c := components[_]
  issue := object.get(c, "issues", [])[_]

  cve := object.get(issue, "reference", "")
  score := to_number(object.get(issue, "severity", 0))

  startswith(cve, "CVE-")
  score > threshold

  finding := {
    "component": object.get(c, "name", "unknown"),
    "cve": cve,
    "score": score
  }
]

max_score := max([f.score | f := high_cves[_]]) {
  count(high_cves) > 0
}

max_score := 0 {
  count(high_cves) == 0
}

action := "Warning" {
  count(high_cves) > 0
}

action := "Pass" {
  count(high_cves) == 0
}

result := {
  "tool": "Nexus IQ",
  "threshold": threshold,
  "action": action,
  "high_cve_count": count(high_cves),
  "max_score": max_score,
  "findings": high_cves
}

deny[msg] {
  count(high_cves) > 0

  msg := sprintf(
    "Nexus IQ Warning: %v CVE(s) found with CVSS score greater than %v. Max score=%v",
    [count(high_cves), threshold, max_score]
  )
}



[
  {
    "outcome": {
      "outputVariables": {
        "NEXUSIQ_JSON": "{\"components\":[{\"name\":\"django:3.2.0\",\"issues\":[{\"reference\":\"CVE-2024-12345\",\"severity\":9.8},{\"reference\":\"CVE-2023-11111\",\"severity\":5.6}]},{\"name\":\"requests:2.28.0\",\"issues\":[]}]}"
      }
    }
  }
]