import os, requests, pathlib

base = "https://huggingface.co/thenlper/gte-small/resolve/main"
files = ["config.json", "vocab.txt", "tokenizer_config.json", "special_tokens_map.json", "model.safetensors"]
out = pathlib.Path("models/gte-small")
out.mkdir(parents=True, exist_ok=True)

for name in files:
    url = f"{base}/{name}"
    path = out / name
    if path.exists():
        continue
    with requests.get(url, stream=True) as r:
        r.raise_for_status()
        with open(path, "wb") as f:
            for chunk in r.iter_content(8192):
                if chunk:
                    f.write(chunk)
