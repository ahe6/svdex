"""Resolve an explicitly reviewed PR for staging; never grants repository writes."""
import json
import os
import re
import subprocess


def validate(pr, checks, comparison):
    if pr.get("state") != "open" or pr.get("draft") or pr["base"]["ref"] != "main":
        raise ValueError("Choose an open, ready PR targeting main")
    sha = pr["head"]["sha"]
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        raise ValueError("Invalid PR revision")
    if comparison.get("status") not in ("ahead", "identical"):
        raise ValueError("Update the PR with current main before previewing")
    for name in ("check", "native"):
        matches = [check for check in checks if check["name"] == name]
        if not matches or any(check["state"] != "SUCCESS" for check in matches):
            raise ValueError(f"PR needs a successful {name} check before previewing")
    return sha


def gh(*args):
    return json.loads(subprocess.check_output(["gh", *args], text=True))


def main():
    number = os.environ.get("PREVIEW_PR", "")
    if not re.fullmatch(r"[1-9][0-9]{0,7}", number):
        raise ValueError("Enter a pull request number")
    repo = "ahe6/svdex"
    pr = gh("api", f"repos/{repo}/pulls/{number}")
    checks = gh("pr", "checks", number, "--repo", repo, "--required", "--json", "name,state")
    comparison = gh("api", f"repos/{repo}/compare/main...{pr['head']['sha']}")
    sha = validate(pr, checks, comparison)
    with open(os.environ["GITHUB_OUTPUT"], "a") as output:
        output.write(f"sha={sha}\n")
    print(f"Reviewed PR #{number}: {sha}")


if __name__ == "__main__":
    main()
