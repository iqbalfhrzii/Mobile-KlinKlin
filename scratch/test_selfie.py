import urllib.request
import json
import ssl

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

base_url = 'https://erp.klinklin.online/api'

# Check with cleaner / CS login
for email, pin in [("cs.surabaya@klinklin.com", "123456"), ("cleaner1@klinklin.com", "123456"), ("admin@klinklin.com", "123456"), ("hrd@klinklin.com", "123456")]:
    try:
        login_data = json.dumps({"email": email, "pin": pin}).encode('utf-8')
        req = urllib.request.Request(f"{base_url}/login", data=login_data, headers={'Content-Type': 'application/json', 'Accept': 'application/json', 'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, context=ctx, timeout=10) as res:
            login_res = json.loads(res.read().decode('utf-8'))
            token = login_res.get('token')
            print(f"Logged in as {email}, token: {token[:15]}...", flush=True)

            # Test selfie endpoint
            req3 = urllib.request.Request(f"{base_url}/absensi/3/selfie", headers={'Authorization': f'Bearer {token}', 'User-Agent': 'Mozilla/5.0'})
            try:
                with urllib.request.urlopen(req3, context=ctx, timeout=10) as res3:
                    print(f"Selfie response for {email}: Status {res3.status}, Content-Type: {res3.headers.get('Content-Type')}, Length: {len(res3.read())} bytes", flush=True)
            except urllib.error.HTTPError as e3:
                print(f"Selfie error for {email}: {e3.code} {e3.read().decode('utf-8')}", flush=True)
    except Exception as e:
        print(f"Failed {email}: {e}", flush=True)
