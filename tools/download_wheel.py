"""Resumable chunked downloader — survives TLS 'record layer' resets on big files.
Re-run safely; it resumes from the partial file. Usage: python download_wheel.py"""
import os, sys, time, urllib.request

URL = "https://download.pytorch.org/whl/cu124/torch-2.6.0%2Bcu124-cp312-cp312-win_amd64.whl"
DEST = os.path.join(os.path.dirname(__file__), "wheels", "torch-2.6.0+cu124-cp312-cp312-win_amd64.whl")
os.makedirs(os.path.dirname(DEST), exist_ok=True)
CHUNK = 8 * 1024 * 1024          # 8 MB requests keep each TLS stream small

def total_size():
    req = urllib.request.Request(URL, method="HEAD")
    with urllib.request.urlopen(req, timeout=60) as r:
        return int(r.headers["Content-Length"])

size = total_size()
have = os.path.getsize(DEST) if os.path.exists(DEST) else 0
print(f"Total {size/1e9:.2f} GB | already have {have/1e9:.2f} GB")
mode = "ab" if have else "wb"
with open(DEST, mode) as f:
    pos = have
    while pos < size:
        end = min(pos + CHUNK - 1, size - 1)
        for attempt in range(12):
            try:
                req = urllib.request.Request(URL, headers={"Range": f"bytes={pos}-{end}"})
                with urllib.request.urlopen(req, timeout=120) as r:
                    data = r.read()
                f.write(data); f.flush()
                pos += len(data)
                print(f"\r{pos/1e9:.2f}/{size/1e9:.2f} GB ({100*pos/size:.1f}%)", end="")
                break
            except Exception as e:
                if attempt == 11:
                    print(f"\nFAILED at {pos} after retries: {e}")
                    sys.exit(1)
                time.sleep(2)
print("\nDONE:", DEST)
