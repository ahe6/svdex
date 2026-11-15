"""Publish a credential-free bundle and wait for a host-written, nonsensitive receipt."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time


def aws(*args):
    return subprocess.run(["aws", *args], check=True, capture_output=True, text=True).stdout


def main():
    sha = os.environ["GITHUB_SHA"]
    run = f'{os.environ["GITHUB_RUN_ID"]}-{os.environ["GITHUB_RUN_ATTEMPT"]}'
    bucket = os.environ["SVDEX_ARTIFACT_BUCKET"]
    instance = os.environ["SVDEX_INSTANCE_ID"]
    if not re.fullmatch(r"[0-9a-f]{40}", sha): raise ValueError("Invalid source revision")
    if not re.fullmatch(r"[0-9]{1,20}-[0-9]{1,5}", run): raise ValueError("Invalid run identifier")
    if not re.fullmatch(r"svdex-discourse-[0-9]{12}-[a-z0-9-]+", bucket): raise ValueError("Invalid release bucket")
    if not re.fullmatch(r"i-[0-9a-f]+", instance): raise ValueError("Invalid host identifier")
    artifact = Path("artifacts/release.tar.gz")
    digest = hashlib.sha256(artifact.read_bytes()).hexdigest()
    aws("s3", "cp", str(artifact), f"s3://{bucket}/releases/github/{run}/release.tar.gz", "--sse", "AES256", "--only-show-errors")
    parameters = json.dumps({"ReleaseSha": [sha], "ArchiveSha256": [digest], "RunId": [run]})
    aws("ssm", "send-command", "--document-name", "SVDEX-DeployReviewedRelease", "--instance-ids", instance, "--parameters", parameters, "--comment", f"SVDEX reviewed release {sha}")
    # No permission to read arbitrary SSM command output or private backups.
    receipt = Path("artifacts/deployment-receipt.json")
    for _ in range(230):
        result = subprocess.run(["aws", "s3", "cp", f"s3://{bucket}/deployments/github/{run}.json", str(receipt), "--only-show-errors"], capture_output=True, text=True)
        if result.returncode == 0:
            data = json.loads(receipt.read_text())
            if data["source_commit"] != sha or data["run_id"] != run:
                raise ValueError("Receipt does not match this release")
            if data["status"] != "success":
                raise RuntimeError(f'Deployment stopped during {data["phase"]}; inspect the private host log')
            print(f"Deployed and verified {sha}")
            return
        time.sleep(15)
    raise TimeoutError("No deployment receipt yet; inspect the host before starting another deployment")


if __name__ == "__main__":
    main()
