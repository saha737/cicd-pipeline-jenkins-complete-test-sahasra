set -e

node <<'NODE'
const fs = require("fs");

const reportFile = "/harness/nexusiq.json";
const outFile = "/harness/regoevalresult.json";
const minFile = "/harness/regoevalresult.min.json";

function arr(x) {
  return Array.isArray(x) ? x : [];
}

function num(x) {
  const n = Number(x);
  return Number.isFinite(n) ? n : 0;
}

function findCve(obj) {
  const m = JSON.stringify(obj).match(/CVE-\d{4}-\d+/i);
  return m ? m[0] : "";
}

function findSeverity(obj) {
  const m = JSON.stringify(obj).match(/severity\s+([0-9]+(\.[0-9]+)?)/i);
  return m ? Number(m[1]) : 0;
}

function compName(c) {
  if (c.displayName) return c.displayName;
  if (c.packageUrl) return c.packageUrl;

  const co = c.componentIdentifier && c.componentIdentifier.coordinates;
  if (co) {
    return [co.groupId || co.namespace, co.artifactId || co.name, co.version]
      .filter(Boolean)
      .join(":");
  }

  return "unknown_component";
}

let result;

if (!fs.existsSync(reportFile)) {
  result = {
    status: "report_not_found",
    report_file: reportFile,
    total_components: 0,
    total_violations: 0,
    total_violations_unwaived: 0,
    high_cve_over_8_count: 0,
    policy_action: "Pass",
    by_policy: {},
    by_threat_category: {},
    by_threat_level: {},
    top_components: [],
    high_cve_over_8: []
  };
} else {
  const report = JSON.parse(fs.readFileSync(reportFile, "utf8"));
  const components = arr(report.components);

  const byPolicy = {};
  const byCategory = {};
  const byLevel = {};
  const topComponents = [];
  const highCves = [];

  let totalViolations = 0;
  let totalUnwaived = 0;

  for (const c of components) {
    const name = compName(c);
    let componentUnwaivedCount = 0;

    const violations = [];

    // Nexus IQ policy violations format
    for (const v of arr(c.violations)) {
      const cve = findCve(v);
      const cvss = num(v.cvssScore) || findSeverity(v) || num(v.policyThreatLevel);

      violations.push({
        policyName: v.policyName || "unknown_policy",
        policyThreatCategory: v.policyThreatCategory || "UNKNOWN",
        policyThreatLevel: num(v.policyThreatLevel || v.threatLevel),
        cvss: cvss,
        cve: cve,
        waived: Boolean(v.waived)
      });
    }

    // Nexus IQ securityIssues format
    for (const s of arr(c.securityData && c.securityData.securityIssues)) {
      violations.push({
        policyName: "Security-CVE",
        policyThreatCategory: "SECURITY",
        policyThreatLevel: num(s.severity || s.cvssScore),
        cvss: num(s.severity || s.cvssScore),
        cve: s.reference || s.cve || findCve(s),
        waived: false
      });
    }

    for (const v of violations) {
      totalViolations++;

      if (!v.waived) {
        totalUnwaived++;
        componentUnwaivedCount++;

        byPolicy[v.policyName] = (byPolicy[v.policyName] || 0) + 1;
        byCategory[v.policyThreatCategory] = (byCategory[v.policyThreatCategory] || 0) + 1;
        byLevel[String(v.policyThreatLevel)] = (byLevel[String(v.policyThreatLevel)] || 0) + 1;

        if (v.cve && v.cvss > 8) {
          highCves.push({
            component: name,
            cve: v.cve,
            cvss: v.cvss,
            policyName: v.policyName,
            policyThreatCategory: v.policyThreatCategory,
            policyThreatLevel: v.policyThreatLevel
          });
        }
      }
    }

    if (componentUnwaivedCount > 0) {
      topComponents.push({
        displayName: name,
        count: componentUnwaivedCount
      });
    }
  }

  topComponents.sort((a, b) => b.count - a.count);
  highCves.sort((a, b) => b.cvss - a.cvss);

  result = {
    status: "completed",
    report_file: reportFile,
    total_components: components.length,
    total_violations: totalViolations,
    total_violations_unwaived: totalUnwaived,
    high_cve_over_8_count: highCves.length,
    policy_action: highCves.length > 0 ? "Warning" : "Pass",
    by_policy: byPolicy,
    by_threat_category: byCategory,
    by_threat_level: byLevel,
    top_components: topComponents.slice(0, 20),
    high_cve_over_8: highCves.slice(0, 25)
  };
}

fs.writeFileSync(outFile, JSON.stringify(result, null, 2));
fs.writeFileSync(minFile, JSON.stringify(result));

console.log("Nexus Rego Evaluation Result:");
console.log(JSON.stringify(result, null, 2));
NODE

export NEXUS_REGO_RESULT="$(cat /harness/regoevalresult.min.json)"

echo "Created file: /harness/regoevalresult.json"
echo "NEXUS_REGO_RESULT=$NEXUS_REGO_RESULT"


NEXUS_REGO_RESULT


package nexus.simple

result := json.unmarshal(input[0].outcome.outputVariables["NEXUS_REGO_RESULT"])

deny[msg] {
  r := json.unmarshal(input[0].outcome.outputVariables["NEXUS_REGO_RESULT"])
  r.status != "completed"

  msg := sprintf("Nexus IQ policy check could not complete. Status=%s, report=%s", [r.status, r.report_file])
}

deny[msg] {
  r := json.unmarshal(input[0].outcome.outputVariables["NEXUS_REGO_RESULT"])
  r.high_cve_over_8_count > 0

  msg := sprintf(
    "Nexus IQ Warning: %v CVE(s) found with CVSS greater than 8. Total components=%v, unwaived violations=%v. Result file=/harness/regoevalresult.json",
    [r.high_cve_over_8_count, r.total_components, r.total_violations_unwaived]
  )
}
