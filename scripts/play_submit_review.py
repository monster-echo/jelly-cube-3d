#!/usr/bin/env python3
"""Promote the Google Play production draft release and send it for review.

Flow: edit -> promote draft release(s) to status=completed -> commit WITHOUT
changesNotSentForReview, which submits the changes to Google Play review.

Exit codes: 0 submitted / 2 unexpected error / 3 platform rule blocks API
(first submission of a DRAFT APP must use the console button once).
"""
import argparse
import json
import os
import sys
import time
import urllib.request

API = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications'


def auth_token(sa):
    import jwt
    now = int(time.time())
    assertion = jwt.encode(
        {'iss': sa['client_email'],
         'scope': 'https://www.googleapis.com/auth/androidpublisher',
         'aud': sa['token_uri'], 'iat': now, 'exp': now + 3600},
        sa['private_key'], algorithm='RS256')
    body = ('grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion='
            + assertion).encode()
    req = urllib.request.Request(sa['token_uri'], data=body,
        headers={'Content-Type': 'application/x-www-form-urlencoded'})
    return json.load(urllib.request.urlopen(req, timeout=60))['access_token']


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--package', default='tech.zhongbei.jellycube3d')
    ap.add_argument('--track', default='production')
    args = ap.parse_args()
    base = f'{API}/{args.package}'
    tok = auth_token(json.loads(os.environ['GOOGLE_PLAY_SERVICE_ACCOUNT_JSON']))
    hdr = {'Authorization': 'Bearer ' + tok, 'Content-Type': 'application/json'}

    def call(method, path, body=None):
        data = json.dumps(body).encode() if body is not None else b''
        req = urllib.request.Request(base + path, data=data, method=method, headers=hdr)
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                raw = r.read()
                return r.status, (json.loads(raw) if raw else {})
        except urllib.error.HTTPError as e:
            raw = e.read()
            try:
                return e.code, json.loads(raw)
            except Exception:
                return e.code, {'raw': raw[:300].decode(errors='replace')}

    s, e = call('POST', '/edits', {})
    edit = e['id']
    s, t = call('GET', f'/edits/{edit}/tracks/{args.track}')
    releases = t.get('releases', [])
    promoted = [dict(r, status='completed') for r in releases if r.get('status') == 'draft']
    if not promoted:
        kept = [r for r in releases if r.get('status') == 'completed']
        if kept:
            print(f'{args.track} already has a completed release; nothing to submit.')
            call('DELETE', f'/edits/{edit}')
            return 0
        print(f'No draft release on {args.track}; run the release workflow first.')
        call('DELETE', f'/edits/{edit}')
        return 2
    s, _ = call('PUT', f'/edits/{edit}/tracks/{args.track}',
                {'track': args.track, 'releases': promoted})
    s, res = call('POST', f'/edits/{edit}:commit')
    if s == 200:
        for r in promoted:
            print(f"submitted to review: {r.get('name')} codes={r.get('versionCodes')}")
        return 0
    msg = json.dumps(res, ensure_ascii=False)
    if 'draft app' in msg:
        print('PLATFORM RULE: first submission of a never-published (draft) app '
              'must be sent from Play Console → 发布概览 → 将应用送审. '
              'This workflow works for every release after the first approval.')
        return 3
    print('commit failed:', s, msg[:300])
    return 2


if __name__ == '__main__':
    sys.exit(main())
