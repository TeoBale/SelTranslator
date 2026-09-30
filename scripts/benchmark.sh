#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
mkdir -p build/benchmark build/measurements
xcrun swiftc -sdk "$DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk" -swift-version 6 -strict-concurrency=complete -O -parse-as-library -target "$(uname -m)-apple-macos26.0" Tools/TranslationBenchmark.swift -o build/benchmark/translation-benchmark
python3 - <<'PYRUN'
import subprocess
from pathlib import Path
for run in range(1, 4):
    result = subprocess.run(['build/benchmark/translation-benchmark'], capture_output=True, timeout=180, check=True)
    Path(f'build/measurements/translation-run-{run}.json').write_bytes(result.stdout)
Path('build/benchmark/results.json').write_bytes(result.stdout)
PYRUN
python3 - <<'PY'
import json, statistics
from pathlib import Path
reports=[json.loads(p.read_text()) for p in sorted(Path('build/measurements').glob('translation-run-*.json'))]
for index, report in enumerate(reports, 1):
    print('run', index, 'statuses', report['statuses'], 'first_request_ms', report['samples'][0]['totalMilliseconds'])
groups={}
for report in reports:
    for sample in report['samples']:
        key=(sample['pair'],sample['ownership'],sample['workload'],sample['outcome'])
        groups.setdefault(key,[]).append(sample['totalMilliseconds'])
summary=[]
for key,values in groups.items():
    values.sort()
    p95=values[min(len(values)-1,__import__('math').ceil(.95*len(values))-1)]
    print(key, 'n=',len(values),'median_ms=',round(statistics.median(values),2),'p95_ms=',round(p95,2))
    summary.append(dict(pair=key[0], ownership=key[1], workload=key[2], outcome=key[3], n=len(values), medianMilliseconds=statistics.median(values), p95Milliseconds=p95))
Path('build/measurements/summary.json').write_text(json.dumps(summary,indent=2)+'\n')
PY
