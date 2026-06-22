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




package nexus.simple

threshold := 8

payload := json.unmarshal(input[0].outcome.outputVariables["NEXUSIQ_JSON"])

components := object.get(payload, "components", [])

policy_findings := [finding |
  c := components[_]
  v := object.get(c, "violations", [])[_]

  finding := {
    "component": object.get(c, "name", "unknown"),
    "source": "violations",
    "policyName": object.get(v, "policyName", "unknown_policy"),
    "threatCategory": object.get(v, "policyThreatCategory", "UNKNOWN"),
    "threatLevel": to_number(object.get(v, "policyThreatLevel", 0)),
    "score": to_number(object.get(v, "cvssScore", object.get(v, "policyThreatLevel", 0))),
    "cve": object.get(v, "cve", object.get(v, "reference", "")),
    "waived": object.get(v, "waived", false)
  }
]

security_findings := [finding |
  c := components[_]
  s := object.get(c, "securityIssues", [])[_]

  finding := {
    "component": object.get(c, "name", "unknown"),
    "source": "securityIssues",
    "policyName": "Security-CVE",
    "threatCategory": "SECURITY",
    "threatLevel": to_number(object.get(s, "severity", object.get(s, "cvssScore", 0))),
    "score": to_number(object.get(s, "severity", object.get(s, "cvssScore", 0))),
    "cve": object.get(s, "reference", object.get(s, "cve", "")),
    "waived": false
  }
]

all_findings := array.concat(policy_findings, security_findings)

unwaived_findings := [f |
  f := all_findings[_]
  not f.waived
]

high_cves := [f |
  f := unwaived_findings[_]
  startswith(f.cve, "CVE-")
  f.score > threshold
]

by_policy := {pname: count([1 |
  f := unwaived_findings[_]
  f.policyName == pname
]) |
  f := unwaived_findings[_]
  pname := f.policyName
}

by_threat_category := {cat: count([1 |
  f := unwaived_findings[_]
  f.threatCategory == cat
]) |
  f := unwaived_findings[_]
  cat := f.threatCategory
}

by_threat_level := {level: count([1 |
  f := unwaived_findings[_]
  sprintf("%v", [f.threatLevel]) == level
]) |
  f := unwaived_findings[_]
  level := sprintf("%v", [f.threatLevel])
}

top_components := [item |
  c := components[_]
  cname := object.get(c, "name", "unknown")

  cnt := count([1 |
    f := unwaived_findings[_]
    f.component == cname
  ])

  cnt > 0

  item := {
    "displayName": cname,
    "count": cnt
  }
]

result := {
  "tool": "Nexus IQ",
  "threshold": threshold,
  "policy_action": "Warning",
  "total_components": count(components),
  "total_findings": count(all_findings),
  "total_unwaived_findings": count(unwaived_findings),
  "high_cve_over_8_count": count(high_cves),
  "high_cve_over_8": high_cves,
  "by_policy": by_policy,
  "by_threat_category": by_threat_category,
  "by_threat_level": by_threat_level,
  "top_components": top_components
} {
  count(high_cves) > 0
}

result := {
  "tool": "Nexus IQ",
  "threshold": threshold,
  "policy_action": "Pass",
  "total_components": count(components),
  "total_findings": count(all_findings),
  "total_unwaived_findings": count(unwaived_findings),
  "high_cve_over_8_count": 0,
  "high_cve_over_8": [],
  "by_policy": by_policy,
  "by_threat_category": by_threat_category,
  "by_threat_level": by_threat_level,
  "top_components": top_components
} {
  count(high_cves) == 0
}

deny[msg] {
  count(high_cves) > 0

  msg := sprintf(
    "Nexus IQ Warning: %v CVE(s) found with CVSS score greater than %v. Total components=%v, unwaived findings=%v",
    [
      count(high_cves),
      threshold,
      count(components),
      count(unwaived_findings)
    ]
  )
}



