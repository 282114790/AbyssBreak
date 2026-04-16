#!/usr/bin/env python3
"""Batch Gemini image generation — serial-send, parallel-generate, URL-based lookup.

1. Serial send: open tab → send prompt → wait for conv URL → record mapping → next
2. Parallel generate: up to PARALLEL tabs generating simultaneously
3. Batch URL lookup: single AppleScript call for all tab URLs, cached tab index
4. Extract in-place: Canvas API download from the same tab, then close
"""

import subprocess, time, re, os, sys, shutil, tempfile

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DOWNLOADS_DIR = os.path.expanduser("~/Downloads")

PARALLEL = 10
MAX_ENTRIES = 999
POLL_INTERVAL = 5
MAX_POLL_TIME = 300


def _get_config():
    """Support CLI: batch_gemini_gen.py [prompt_file] [output_dir]"""
    if len(sys.argv) >= 3:
        return sys.argv[1], sys.argv[2]
    elif len(sys.argv) == 2:
        return sys.argv[1], os.path.join(SCRIPT_DIR, "raw_tiles/output")
    else:
        return (os.path.join(SCRIPT_DIR, "prompt_export/prompts_deco_props_dungeon.txt"),
                os.path.join(SCRIPT_DIR, "raw_tiles/deco_props_dungeon_new"))


PROMPT_FILE, OUTPUT_DIR = _get_config()


# ── Chrome helpers ──

def chrome_js_tab(tab_idx: int, js_code: str) -> str:
    js_oneline = ' '.join(js_code.split())
    escaped = js_oneline.replace('\\', '\\\\').replace('"', '\\"')
    script = f'''tell application "Google Chrome"
    tell tab {tab_idx} of first window
        set r to execute javascript "{escaped}"
        return r
    end tell
end tell'''
    tmp = tempfile.NamedTemporaryFile(mode='w', suffix='.applescript', delete=False, encoding='utf-8')
    tmp.write(script)
    tmp.close()
    try:
        result = subprocess.run(["osascript", tmp.name], capture_output=True, text=True, timeout=60)
        return result.stdout.strip()
    except subprocess.TimeoutExpired:
        return "ERROR: timeout"
    except Exception as e:
        return f"ERROR: {e}"
    finally:
        os.unlink(tmp.name)


def as_run(script: str) -> str:
    r = subprocess.run(["osascript", "-e", script], capture_output=True, text=True, timeout=15)
    return r.stdout.strip()


def get_tab_count() -> int:
    r = as_run('tell application "Google Chrome" to return count of tabs of first window')
    return int(r) if r.isdigit() else 0


def get_tab_url(idx: int) -> str:
    return as_run(f'tell application "Google Chrome" to return URL of tab {idx} of first window')


def get_all_tab_urls() -> list[str]:
    """Single AppleScript call to get all tab URLs — O(1) instead of O(n)."""
    r = as_run(
        'tell application "Google Chrome" to return URL of every tab of first window'
    )
    if not r:
        return []
    return [u.strip() for u in r.split(", ")]


def open_new_tab(url: str) -> int:
    as_run(f'tell application "Google Chrome" to tell first window to make new tab with properties {{URL:"{url}"}}')
    time.sleep(0.5)
    return get_tab_count()


def close_tab(idx: int):
    as_run(f'tell application "Google Chrome" to tell first window to close tab {idx}')


def find_tab_by_url(target_url: str) -> int | None:
    """Batch lookup: single AppleScript call, then linear scan in Python."""
    urls = get_all_tab_urls()
    for i, u in enumerate(urls):
        if u == target_url:
            return i + 1
    return None


def resolve_tab(job: dict) -> int | None:
    """Use cached tab_idx if still valid, otherwise fallback to batch lookup."""
    tidx = job.get("tab_idx")
    if tidx:
        try:
            actual = get_tab_url(tidx)
            if actual == job["conv_url"]:
                return tidx
        except Exception:
            pass
    tidx = find_tab_by_url(job["conv_url"])
    if tidx:
        job["tab_idx"] = tidx
    return tidx


# ── Prompt parsing ──

def parse_prompts(filepath: str) -> list:
    entries = []
    with open(filepath, "r") as f:
        lines = f.readlines()
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        m = re.match(r"^---\s*\[(.+?)\]\s*---$", line)
        if m:
            filename = m.group(1)
            i += 1
            while i < len(lines) and lines[i].strip() == "":
                i += 1
            prompt = lines[i].strip() if i < len(lines) else ""
            entries.append({"filename": filename, "prompt": prompt})
        i += 1
    return entries


def is_valid(filepath: str) -> bool:
    if not os.path.exists(filepath):
        return False
    r = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", filepath],
                       capture_output=True, text=True, timeout=10)
    return "pixelWidth: 1024" in r.stdout and "pixelHeight: 1024" in r.stdout


# ── Core operations ──

def switch_to_pro_mode(tidx: int):
    """Switch Gemini model from '快速' to 'Pro' via the mode switcher dropdown."""
    chrome_js_tab(tidx,
        "(function(){ var sw=document.querySelector('bard-mode-switcher button'); "
        "if(sw) sw.click(); })()")
    time.sleep(0.8)
    chrome_js_tab(tidx,
        "(function(){ var items=document.querySelectorAll('[role=menuitem]'); "
        "for(var i=0;i<items.length;i++){ "
        "var t=items[i].querySelector('.mode-title'); "
        "if(t&&t.textContent.trim()==='Pro'){items[i].click();return 'OK';}} "
        "return 'NO'; })()")
    time.sleep(0.5)


def send_prompt_in_new_tab(prompt: str) -> tuple[str | None, int | None]:
    """Open new tab, switch to Pro + image mode, fill prompt, send.
    Returns (conv_url, tab_idx) or (None, None) on failure."""
    tidx = open_new_tab("https://gemini.google.com/app")
    time.sleep(3)

    switch_to_pro_mode(tidx)

    chrome_js_tab(tidx,
        "(function(){ var btns=document.querySelectorAll('button'); "
        "for(var i=0;i<btns.length;i++){if((btns[i].textContent||'').indexOf('制作图片')>=0)"
        "{btns[i].click();break;}} })()")
    time.sleep(1)

    escaped = prompt.replace('\\', '\\\\').replace("'", "\\'")
    r = chrome_js_tab(tidx,
        f"(function(){{ var el=document.querySelector('.ql-editor'); "
        f"if(!el) return 'ERR'; el.focus(); el.innerText='{escaped}'; "
        f"el.dispatchEvent(new Event('input',{{bubbles:true}})); return 'OK'; }})()")
    if 'ERR' in r:
        print(f"[fill failed: {r}]", flush=True)
        return None, None
    time.sleep(0.5)

    chrome_js_tab(tidx,
        "(function(){ var btns=document.querySelectorAll('button'); "
        "for(var i=0;i<btns.length;i++){var l=btns[i].getAttribute('aria-label')||''; "
        "if(l==='发送'){btns[i].click();return 'SENT';}} return 'NO'; })()")

    for _ in range(15):
        time.sleep(1)
        u = get_tab_url(tidx)
        if '/app/' in u and u != 'https://gemini.google.com/app':
            return u, tidx

    print("[URL did not change]", flush=True)
    return None, None


def poll_job(job: dict) -> str:
    """Check image status via cached tab index. Returns 'ready'|'generating'|'failed'."""
    tidx = resolve_tab(job)
    if tidx is None:
        return "failed"

    elapsed = time.time() - job["start"]

    r = chrome_js_tab(tidx,
        "(function(){ "
        "var img=document.querySelector('img.image.loaded'); "
        "if(img && img.naturalWidth>=512) return 'READY:'+img.naturalWidth+'x'+img.naturalHeight; "
        "var img2=document.querySelector('img.image'); "
        "if(img2 && img2.naturalWidth>=512) return 'READY:'+img2.naturalWidth+'x'+img2.naturalHeight; "
        "if(img2) return 'LOADING:'+img2.naturalWidth; "
        "var text=document.body?document.body.innerText:''; "
        "if(text.indexOf('正在创建')>=0 || text.indexOf('Creating')>=0) return 'CREATING'; "
        "return 'WAITING'; })()")

    if r.startswith("READY"):
        return "ready"
    if elapsed > MAX_POLL_TIME:
        return "failed"
    return "generating"


def extract_job(job: dict, filename: str) -> bool:
    """Extract image via Canvas from cached tab index, download, validate."""
    tidx = resolve_tab(job)
    if tidx is None:
        print("[tab not found]", end=" ", flush=True)
        return False

    dl_path = os.path.join(DOWNLOADS_DIR, filename)
    if os.path.exists(dl_path):
        os.remove(dl_path)

    safe_fn = filename.replace("'", "\\'")
    r = chrome_js_tab(tidx,
        f"(function(){{ "
        f"var img=document.querySelector('img.image.loaded') || document.querySelector('img.image'); "
        f"if(!img||img.naturalWidth<100) return 'ERR:no_img_'+document.querySelectorAll('img').length; "
        f"var c=document.createElement('canvas'); "
        f"c.width=img.naturalWidth; c.height=img.naturalHeight; "
        f"c.getContext('2d').drawImage(img,0,0); "
        f"var a=document.createElement('a'); a.download='{safe_fn}'; "
        f"a.href=c.toDataURL('image/png'); "
        f"document.body.appendChild(a); a.click(); document.body.removeChild(a); "
        f"return 'OK:'+img.naturalWidth+'x'+img.naturalHeight; }})()")

    if "ERR" in r or "ERROR" in r:
        print(f"[js:{r}]", end=" ", flush=True)
        return False

    for _ in range(20):
        if os.path.exists(dl_path) and os.path.getsize(dl_path) > 1000:
            break
        time.sleep(1)
    else:
        print("[dl timeout]", end=" ", flush=True)
        return False

    dst = os.path.join(OUTPUT_DIR, filename)
    shutil.move(dl_path, dst)
    if not is_valid(dst):
        print("[invalid 1024x1024]", end=" ", flush=True)
        return False
    return True


def close_job_tab(job: dict):
    """Find and close the tab for this job."""
    tidx = resolve_tab(job)
    if tidx is not None:
        close_tab(tidx)
        time.sleep(0.2)


# ── Main ──

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    all_entries = parse_prompts(PROMPT_FILE)[:MAX_ENTRIES]

    existing = [e for e in all_entries
                if is_valid(os.path.join(OUTPUT_DIR, e['filename']))]
    skip_names = {e['filename'] for e in existing}
    todo = [e for e in all_entries if e['filename'] not in skip_names]

    print(f"Total: {len(all_entries)}, already done: {len(existing)}, to generate: {len(todo)}")
    print(f"Parallel: {PARALLEL}, poll: {POLL_INTERVAL}s, timeout: {MAX_POLL_TIME}s")
    print(f"Output: {OUTPUT_DIR}\n")

    if not todo:
        print("All done!")
        return

    as_run('tell application "Google Chrome" to activate')

    queue = list(todo)
    active = []   # list of {filename, conv_url, start, tab_idx}
    succeeded = list(skip_names)
    failed = []

    while queue or active:
        # ── Phase A: fill parallel slots (serial, one at a time) ──
        while queue and len(active) < PARALLEL:
            entry = queue.pop(0)
            short = entry['filename']
            print(f"[SEND]   {short} — opening tab...", flush=True)

            conv_url, tidx = send_prompt_in_new_tab(entry['prompt'])

            if conv_url:
                conv_id = conv_url.split('/')[-1][:16]
                print(f"         ✓ URL: /app/{conv_id}", flush=True)
                active.append({
                    "filename": entry['filename'],
                    "conv_url": conv_url,
                    "start": time.time(),
                    "tab_idx": tidx,
                })
            else:
                print(f"         ✗ send failed, skipping", flush=True)
                failed.append(entry['filename'])

        if not active:
            break

        # ── Phase B: poll all active jobs ──
        time.sleep(POLL_INTERVAL)

        done_jobs = []
        for job in active:
            short = job['filename']
            elapsed = int(time.time() - job['start'])
            status = poll_job(job)

            if status == "ready":
                print(f"[READY]  {short} ({elapsed}s) — extracting...", end=" ", flush=True)
                ok = extract_job(job, job['filename'])
                if ok:
                    sz = os.path.getsize(os.path.join(OUTPUT_DIR, job['filename'])) // 1024
                    print(f"OK ({sz}KB)")
                    succeeded.append(job['filename'])
                else:
                    print("FAIL")
                    failed.append(job['filename'])
                close_job_tab(job)
                done_jobs.append(job)

            elif status == "failed":
                print(f"[TIMEOUT] {short} ({elapsed}s)")
                failed.append(job['filename'])
                close_job_tab(job)
                done_jobs.append(job)

            else:
                print(f"[POLL]   {short} ({elapsed}s) generating...", flush=True)

        for j in done_jobs:
            active.remove(j)

    # ── Summary ──
    print(f"\n{'='*50}")
    print(f"Done: {len(succeeded)} ok, {len(failed)} failed / {len(all_entries)} total")
    if succeeded:
        print("Succeeded:")
        for f in sorted(succeeded):
            print(f"  ✓ {f}")
    if failed:
        print("Failed:")
        for f in failed:
            print(f"  ✗ {f}")


if __name__ == "__main__":
    main()
