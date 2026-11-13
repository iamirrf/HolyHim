#!/usr/bin/env python3
"""Create or complete HolyHim's own RevenueCat project and catalog.

Idempotent, through the signed-in RevenueCat CLI (`rc api`, OAuth): project
"HolyHim", an App Store app for com.holyhim.app, the non-consumable product
holyhim_lifetime, the `lifetime` entitlement with that product attached, and
a default offering with a lifetime package. Writes public identifiers to
config/revenuecat.json, config/revenuecat-public.json and
lib/services/billing_config.dart. HolyHer's project is never read or changed.

With --webhook, also points RevenueCat's webhook at HolyHim's function, using
the bearer secret already stored in HolyHim's Secret Manager (it is passed
to RevenueCat through stdin and never printed or written to disk).

  python3 tool/setup_revenuecat.py [--webhook]
"""
from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CLOUD = json.loads((ROOT / 'config/cloud.json').read_text())
NAME, BUNDLE, PRODUCT, ENTITLEMENT = 'HolyHim', 'com.holyhim.app', 'holyhim_lifetime', 'lifetime'


def rc(method: str, path: str, body: dict | None = None, secret_body: str | None = None) -> dict:
    command = ['rc', 'api', method, path, '--json', '--no-input']
    data = None
    if body is not None or secret_body is not None:
        command += ['--body', '@-']
        data = secret_body if secret_body is not None else json.dumps(body)
    result = subprocess.run(command, input=data, capture_output=True, text=True)
    if result.returncode:
        raise SystemExit(f'rc api {method} {path} failed: {(result.stdout + result.stderr).strip()[:500]}')
    return json.loads(result.stdout) if result.stdout.strip() else {}


def items(path: str) -> list[dict]:
    rows, url = [], path
    while url:
        page = rc('GET', url)
        rows += page.get('items', [])
        nxt = page.get('next_page')
        url = nxt.split('/v2', 1)[1] if nxt else None
    return rows


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--webhook', action='store_true')
    args = parser.parse_args()

    project = next((p for p in items('/projects') if p.get('name') == NAME), None) or rc('POST', '/projects', {'name': NAME})
    pid = project['id']
    base = f'/projects/{pid}'
    print('project', pid)

    app = next((a for a in items(f'{base}/apps') if a.get('type') == 'app_store'
                and (a.get('app_store') or {}).get('bundle_id') == BUNDLE), None)
    app = app or rc('POST', f'{base}/apps', {'name': 'HolyHim iOS', 'type': 'app_store',
                                             'app_store': {'bundle_id': BUNDLE}})
    print('app', app['id'])

    product = next((p for p in items(f'{base}/products') if p.get('store_identifier') == PRODUCT
                    and p.get('app_id') == app['id']), None)
    product = product or rc('POST', f'{base}/products', {'store_identifier': PRODUCT, 'app_id': app['id'],
                                                        'type': 'non_consumable', 'display_name': 'HolyHim Lifetime'})
    print('product', product['id'])

    entitlement = next((e for e in items(f'{base}/entitlements') if e.get('lookup_key') == ENTITLEMENT), None)
    entitlement = entitlement or rc('POST', f'{base}/entitlements', {'lookup_key': ENTITLEMENT,
                                                                    'display_name': 'Lifetime access'})
    attached = {p['id'] for p in items(f"{base}/entitlements/{entitlement['id']}/products")}
    if product['id'] not in attached:
        rc('POST', f"{base}/entitlements/{entitlement['id']}/actions/attach_products", {'product_ids': [product['id']]})
    print('entitlement', entitlement['id'])

    offering = next((o for o in items(f'{base}/offerings') if o.get('lookup_key') == 'default'), None)
    offering = offering or rc('POST', f'{base}/offerings', {'lookup_key': 'default', 'display_name': 'Default'})
    if not offering.get('is_current'):
        rc('POST', f"{base}/offerings/{offering['id']}", {'is_current': True})
    package = next((p for p in items(f"{base}/offerings/{offering['id']}/packages")
                    if p.get('lookup_key') == '$rc_lifetime'), None)
    package = package or rc('POST', f"{base}/offerings/{offering['id']}/packages",
                            {'lookup_key': '$rc_lifetime', 'display_name': 'Lifetime', 'position': 1})
    in_package = {(p.get('product') or p).get('id') for p in items(f"{base}/packages/{package['id']}/products")}
    if product['id'] not in in_package:
        rc('POST', f"{base}/packages/{package['id']}/actions/attach_products",
           {'products': [{'product_id': product['id'], 'eligibility_criteria': 'all'}]})
    print('offering', offering['id'])

    keys = items(f"{base}/apps/{app['id']}/public_api_keys")
    public = next((k['key'] for k in keys if str(k.get('key', '')).startswith('appl_')), '')
    if not public:
        raise SystemExit('RevenueCat returned no public App Store SDK key for HolyHim.')

    config = {'projectId': pid, 'appId': app['id'], 'entitlementId': entitlement['id'],
              'entitlementLookupKey': ENTITLEMENT, 'offeringId': offering['id'], 'productId': product['id'],
              'storeProductId': PRODUCT, 'priceUSD': 1.99}
    (ROOT / 'config/revenuecat.json').write_text(json.dumps(config, indent=2) + '\n')
    (ROOT / 'config/revenuecat-public.json').write_text(json.dumps({'iosPublicApiKey': public}, indent=2) + '\n')
    (ROOT / 'lib/services/billing_config.dart').write_text(
        "// Public iOS SDK key. Server credentials never belong in the client.\n"
        f"const revenueCatIosPublicKey = '{public}';\n")
    print('public SDK key and identifiers written to config/ and billing_config.dart')

    if args.webhook:
        account, project_id = CLOUD['account'], CLOUD['projectId']
        secret = subprocess.run(['gcloud', 'secrets', 'versions', 'access', 'latest', '--secret=REVENUECAT_WEBHOOK_SECRET',
                                 f'--project={project_id}', f'--account={account}', '--quiet'],
                                capture_output=True, text=True, check=True).stdout.strip()
        url = f'https://us-central1-{project_id}.cloudfunctions.net/revenuecatWebhook'
        existing = next((w for w in items(f'{base}/integrations/webhooks') if w.get('name') == 'HolyHim backend'), None)
        body = json.dumps({'name': 'HolyHim backend', 'url': url, 'authorization_header': 'Bearer ' + secret})
        path = f'{base}/integrations/webhooks' + (f"/{existing['id']}" if existing else '')
        rc('POST', path, secret_body=body)
        print('webhook ->', url)


if __name__ == '__main__':
    main()
