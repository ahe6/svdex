"""Send only validated public JSON to the installed content importer. No code deploy."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time


def main():
    sha, run = os.environ['GITHUB_SHA'], f"{os.environ['GITHUB_RUN_ID']}-{os.environ['GITHUB_RUN_ATTEMPT']}"
    bucket, instance = os.environ['SVDEX_ARTIFACT_BUCKET'], os.environ['SVDEX_INSTANCE_ID']
    if not re.fullmatch(r'[0-9a-f]{40}', sha): raise ValueError('Invalid revision')
    if not re.fullmatch(r'[0-9]{1,20}-[0-9]{1,5}', run): raise ValueError('Invalid run')
    if not re.fullmatch(r'svdex-(?:discourse|staging)-[0-9]{12}-us-east-1', bucket): raise ValueError('Invalid content bucket')
    if not re.fullmatch(r'i-[0-9a-f]+', instance): raise ValueError('Invalid host')
    path = Path('artifacts/public-catalog.json')
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    subprocess.run(['aws', 's3', 'cp', str(path), f's3://{bucket}/catalog/github/{run}/bundle.json', '--sse', 'AES256', '--only-show-errors'], check=True)
    params = json.dumps({'SourceCommit': [sha], 'BundleSha256': [digest], 'RunId': [run]})
    subprocess.run(['aws', 'ssm', 'send-command', '--document-name', 'SVDEX-SyncPublicCatalog', '--instance-ids', instance, '--parameters', params, '--comment', f'SVDEX reviewed public content {sha}'], check=True, capture_output=True)
    receipt = Path('artifacts/catalog-receipt.json')
    for _ in range(60):
        result = subprocess.run(['aws', 's3', 'cp', f's3://{bucket}/catalog/receipts/{run}.json', str(receipt), '--only-show-errors'], capture_output=True, text=True)
        if result.returncode == 0:
            data = json.loads(receipt.read_text())
            if data.get('source_commit') != sha or data.get('bundle_sha256') != digest or data.get('run_id') != run: raise ValueError('Mismatched sync receipt')
            if data.get('status') != 'success': raise RuntimeError('Content import refused; inspect the private host log')
            print('Reviewed public content synced; no application build or restart.')
            return
        time.sleep(5)
    raise TimeoutError('Content receipt not available; inspect host before retrying')


if __name__ == '__main__':
    main()
