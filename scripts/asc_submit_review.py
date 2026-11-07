#!/usr/bin/env python3
"""Submit an App Store version for review via the ASC API.

Flow: find app -> find IOS version -> attach newest VALID build if missing ->
find/create open review submission -> add version item (+ first READY_TO_SUBMIT
non-consumable IAP version) -> PATCH submitted=true.

Exit codes: 0 submitted / 2 unexpected error / 3 platform rule blocks API
(a version previously rejected then edited locks its submission to the web UI).
"""
import argparse
import json
import os
import pathlib
import sys
import time
import urllib.parse
import urllib.request

import jwt

API = 'https://api.appstoreconnect.apple.com/v1'
BUNDLE_ID = 'tech.zhongbei.jellycube3d'
EDITABLE = {'PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'METADATA_REJECTED', 'REJECTED'}


def token():
    key = os.environ['APPSTORE_PRIVATE_KEY'].replace('\\n', '\n')
    now = int(time.time())
    return jwt.encode({'iss': os.environ['APPSTORE_ISSUER'], 'iat': now,
                       'exp': now + 900, 'aud': 'appstoreconnect-v1'}, key,
                      algorithm='ES256', headers={'kid': os.environ['APPSTORE_KEY_ID']})


def call(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    last = None
    for attempt in range(3):
        req = urllib.request.Request(API + path, data=data, method=method, headers={
            'Authorization': 'Bearer ' + token(), 'Content-Type': 'application/json'})
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
        except Exception as e:
            last = e
            time.sleep(2 * (attempt + 1))
    return 0, {'raw': f'network error: {last}'}


def errs(body):
    return ' | '.join(e.get('detail', '') or e.get('title', '')
                      for e in (body.get('errors') or []) if isinstance(body, dict))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--version', required=True)
    args = ap.parse_args()

    s, apps = call('GET', '/apps?' + urllib.parse.urlencode({'filter[bundleId]': BUNDLE_ID}))
    app_id = (apps.get('data') or [{}])[0].get('id')
    if not app_id:
        print('ASC app not found'); return 2

    q = urllib.parse.urlencode({'filter[versionString]': args.version, 'limit': 10})
    s, vers = call('GET', f'/apps/{app_id}/appStoreVersions?' + q)
    version = next((v for v in (vers.get('data') or [])
                    if v['attributes'].get('platform') == 'IOS'), None)
    if version is None:
        print(f'Version {args.version} does not exist in ASC yet.'); return 2
    vid = version['id']
    state = version['attributes'].get('appStoreState')
    print(f'version {args.version} [{state}]')

    # attach newest VALID build if the version has none
    s, builds = call('GET', '/builds?' + urllib.parse.urlencode(
        {'filter[app]': app_id, 'filter[processingState]': 'VALID', 'limit': 10,
         'sort': '-uploadedDate', 'include': 'appStoreVersion'}))
    attached = None
    s2, cur = call('GET', f'/appStoreVersions/{vid}?include=build')
    for i in cur.get('included', []):
        if i['type'] == 'builds':
            attached = i['id']
    if attached is None:
        cand = next((b for b in (builds.get('data') or [])), None)
        if cand:
            s, _ = call('PATCH', f'/appStoreVersions/{vid}', {'data': {
                'type': 'appStoreVersions', 'id': vid,
                'relationships': {'build': {'data': {'type': 'builds', 'id': cand['id']}}}}})
            print(f'attached build {cand["attributes"].get("version")} -> HTTP {s}')
            if s != 200:
                print(errs(_)); return 2
    elif state in EDITABLE:
        s, _ = call('PATCH', f'/appStoreVersions/{vid}', {'data': {
            'type': 'appStoreVersions', 'id': vid,
            'relationships': {'build': {'data': {'type': 'builds', 'id': attached}}}}})

    # open submission (reuse READY_FOR_REVIEW, else create)
    s, subs = call('GET', f'/apps/{app_id}/reviewSubmissions?limit=10')
    sub = next((x for x in (subs.get('data') or [])
                if x['attributes'].get('state') in ('READY_FOR_REVIEW', 'WAITING_FOR_REVIEW')), None)
    if sub is None:
        s, created = call('POST', '/reviewSubmissions', {'data': {
            'type': 'reviewSubmissions', 'attributes': {'platform': 'IOS'},
            'relationships': {'app': {'data': {'type': 'apps', 'id': app_id}}}}})
        if s != 201:
            print('create submission failed:', s, errs(created)); return 2
        sub = created['data']
    sid = sub['id']

    # items: version + first READY_TO_SUBMIT IAP
    have = set()
    s, items = call('GET', f'/reviewSubmissions/{sid}/items?limit=20')
    for it in (items.get('data') or []):
        rel = it.get('relationships', {})
        if rel.get('appStoreVersion', {}).get('data'):
            have.add('ver')
        if rel.get('inAppPurchaseVersion', {}).get('data'):
            have.add('iap')
    if 'ver' not in have:
        s, res = call('POST', '/reviewSubmissionItems', {'data': {
            'type': 'reviewSubmissionItems',
            'relationships': {
                'reviewSubmission': {'data': {'type': 'reviewSubmissions', 'id': sid}},
                'appStoreVersion': {'data': {'type': 'appStoreVersions', 'id': vid}}}}})
        if s != 201:
            print('add version item failed:', s, errs(res))
            return 3 if 'already added to another reviewSubmission' in json.dumps(res) else 2
    s, iaps = call('GET', f'/apps/{app_id}/inAppPurchasesV2?limit=10')
    iap_id = next((x['id'] for x in (iaps.get('data') or [])
                   if x['attributes'].get('state') == 'READY_TO_SUBMIT'), None)
    if iap_id and 'iap' not in have:
        s2, iv = call('GET', f'/inAppPurchasesV2/{iap_id}/inAppPurchaseVersions?limit=1')
        iap_ver = next((x['id'] for x in ((iv.get('data') or []))), None)
        if iap_ver:
            s, res = call('POST', '/reviewSubmissionItems', {'data': {
                'type': 'reviewSubmissionItems',
                'relationships': {
                    'reviewSubmission': {'data': {'type': 'reviewSubmissions', 'id': sid}},
                    'inAppPurchaseVersion': {'data': {'type': 'inAppPurchaseVersions',
                                                      'id': iap_ver}}}}})
            print(f'added IAP item -> HTTP {s}')

    # submit
    s, res = call('PATCH', f'/reviewSubmissions/{sid}', {'data': {
        'type': 'reviewSubmissions', 'id': sid, 'attributes': {'submitted': True}}})
    if s == 200:
        print('SUBMITTED FOR REVIEW:', res['data']['attributes'].get('state'))
        return 0
    detail = errs(res)
    print('submit failed:', s, detail)
    if 'not ready to be submitted' in detail or 'another reviewSubmission' in detail:
        print('PLATFORM RULE: a version rejected once then edited must be resubmitted '
              'from the App Store Connect web button (提交以供审核). This workflow '
              'covers every fresh version from 1.0.1 onward.')
        return 3
    return 2


if __name__ == '__main__':
    sys.exit(main())
