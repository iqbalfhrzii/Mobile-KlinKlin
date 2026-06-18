import urllib.request
import json

base_url = 'http://192.168.1.25:8000/api'

# Login
login_data = json.dumps({
    "email": "cs@klinklin.com",
    "pin": "123456"
}).encode('utf-8')

req = urllib.request.Request(f"{base_url}/login", data=login_data, headers={'Content-Type': 'application/json', 'Accept': 'application/json'})

try:
    with urllib.request.urlopen(req) as res:
        login_res = json.loads(res.read().decode('utf-8'))
        token = login_res.get('token')
        print(f"Token: {token}")

        # Fetch Karyawans
        req2 = urllib.request.Request(f"{base_url}/karyawans", headers={'Authorization': f'Bearer {token}', 'Accept': 'application/json'})
        with urllib.request.urlopen(req2) as res2:
            data = json.loads(res2.read().decode('utf-8'))
            items = data.get('data', [])
            if isinstance(items, dict) and 'data' in items:
                items = items['data']
            
            if items:
                print("First Karyawan:")
                print(json.dumps(items[0], indent=2))
            else:
                print(f"Data: {data}")
except urllib.error.HTTPError as e:
    print(f"HTTP Error: {e.code}")
    print(e.read().decode('utf-8'))
except Exception as e:
    print(f"Error: {e}")
