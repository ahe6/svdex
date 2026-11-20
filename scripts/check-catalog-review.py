"""Content automation accepts a current main commit merged through a reviewed PR."""
import json
import os
import subprocess


def gh(path):
    return json.loads(subprocess.check_output(['gh', 'api', path], text=True))


def main():
    repo, sha = os.environ['GITHUB_REPOSITORY'], os.environ['GITHUB_SHA']
    if repo != 'ahe6/svdex' or os.environ['GITHUB_REF'] != 'refs/heads/main': raise ValueError('Only the upstream main branch may publish content')
    if gh(f'repos/{repo}/git/ref/heads/main')['object']['sha'] != sha: raise ValueError('Stale content revision; newer main must sync instead')
    prs = gh(f'repos/{repo}/commits/{sha}/pulls')
    for pr in prs:
        if not pr.get('merged_at') or pr.get('draft') or pr['base']['ref'] != 'main' or pr.get('merge_commit_sha') != sha: continue
        reviews = gh(f'repos/{repo}/pulls/{pr["number"]}/reviews')
        latest = {}
        for review in reviews:
            if review['state'] in ('APPROVED', 'CHANGES_REQUESTED', 'DISMISSED'): latest[review['user']['login']] = review['state']
        # The sole maintainer's explicit merge is approval for their own PR;
        # other contributors require an approved review by a writing maintainer.
        if (pr.get('merged_by') or {}).get('login') == 'ahe6': return
        detail = gh(f'repos/{repo}/pulls/{pr["number"]}')
        if (detail.get('merged_by') or {}).get('login') == 'ahe6': return
        for login, state in latest.items():
            if state == 'APPROVED' and gh(f'repos/{repo}/collaborators/{login}/permission')['permission'] in ('admin', 'maintain', 'write'): return
    raise ValueError('A reviewed, merged main-branch PR is required; direct pushes do not publish content')


if __name__ == '__main__': main()
