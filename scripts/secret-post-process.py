#!/user/bin/env python3

#
# this file takes output of Yelp's secret-detect from standard input and process it
#
# $ pip install detect-secrets
#
# $ detect-secrets scan | python3 ./scripts/secret-post-process.py ; echo $?
#
# To suppress a secret, add this comment at the end of line in yaml
# `# pragma: allowlist secret`

import json
import sys
import os

whiteList = [
  "helm-chart-sources/pulsar-monitor/values.yaml",
  "helm-chart-sources/pulsar/ci/test-tls-values.yaml"
]

stdin=''

for line in sys.stdin:
  if line == "\n":
    lb += 1
    if lb == 2:
        break
  else:
    lb = 0

    stdin += line

results = json.loads(stdin)

error = False
for (k, v) in results["results"].items():
    if k not in whiteList:
        print(k, v)
        error = True

if error:
    print("Error: above secret detected")
    os._exit(3)
else:
    print("successful")
