"""Require a host-written staging proof for exactly this source tree."""
import json
from pathlib import Path
import re
import subprocess
import sys


def verify(proof, tree):
    if not re.fullmatch(r"[0-9a-f]{40}", tree):
        raise ValueError("Invalid source tree")
    if proof.get("hostname") != "staging.svdex.com" or proof.get("status") != "success" or proof.get("phase") != "complete":
        raise ValueError("Staging verification has not completed")
    if proof.get("source_tree") != tree:
        raise ValueError("Deploy this exact source to staging before merging/releasing")


if __name__ == "__main__":
    tree = subprocess.check_output(["git", "rev-parse", "HEAD^{tree}"], text=True).strip()
    verify(json.loads(Path(sys.argv[1]).read_text()), tree)
    print("Matching staging preview verified")
