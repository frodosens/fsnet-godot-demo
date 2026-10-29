#!/usr/bin/env python3
"""Reject engine/script diagnostics even when the child mistakenly exits zero."""
import re
import subprocess
import sys

FAILURE = re.compile(r"SCRIPT ERROR|\bERROR:|\bFAIL(?:URE)?(?:\s|:)|Assertion failed|\bfailures\s*=\s*[1-9]\d*", re.IGNORECASE)

def main(argv):
    if not argv:
        print("checked runner requires a command", file=sys.stderr)
        return 2
    result = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    sys.stdout.write(result.stdout)
    if result.returncode:
        return result.returncode if result.returncode > 0 else 1
    if FAILURE.search(result.stdout):
        print("CHECKED_RUNNER: child reported an error despite exit status 0", file=sys.stderr)
        return 1
    return 0

if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
