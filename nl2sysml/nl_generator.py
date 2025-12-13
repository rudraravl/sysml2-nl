#!/usr/bin/env python3
# wikipedia_targets.py
import csv, json, os, re, time, urllib.parse, requests
from collections import defaultdict
try:
    # Optionally load environment variables from a .env file if present
    from dotenv import load_dotenv  # type: ignore
    load_dotenv()
except Exception:
    pass

WIKI_API = "https://en.wikipedia.org/w/api.php"
_DEFAULT_UA = "sysml2-nl-harvester/0.1 (+https://github.com/; contact: set WIKI_USER_AGENT)"

# Create a single session with a proper User-Agent per Wikimedia policy
SESSION = requests.Session()
SESSION.headers.update({
    "User-Agent": os.getenv("WIKI_USER_AGENT", _DEFAULT_UA),
    "Accept": "application/json"
})

# ---- 1) Configure sources (titles) ----
CATEGORY_SOURCES = [
    # broad engineering sources
    {"type": "category", "title": "Category:Robots", "domain": "robotics"},
    {"type": "category", "title": "Category:Medical_devices", "domain": "medical"},
    {"type": "category", "title": "Category:Medical_equipment", "domain": "medical"},
    {"type": "category", "title": "Category:Pumps", "domain": "energy"},
]

PAGE_SOURCES = [
    # list pages we will parse for section items
    {"type": "listpage", "title": "List_of_sensors", "domain": "sensing"},
    {"type": "page", "title": "Home_automation", "domain": "smarthome"},
    {"type": "page", "title": "Index_of_home_automation_articles", "domain": "smarthome"},
    {"type": "page", "title": "List_of_home_automation_software", "domain": "smarthome"},
    {"type": "page", "title": "Pump", "domain": "energy"},
    {"type": "page", "title": "List_of_NASA_robots", "domain": "aerospace"},
]

# ---- 2) Helpers ----
def wiki_api(params, retries: int = 5):
    """Call the Wikipedia API with retries and a friendly User-Agent.

    Retries on transient errors and common throttle statuses (403/429/5xx)
    with exponential backoff.
    """
    params = {"format": "json", "formatversion": "2", **params}
    backoff = 1.0
    last_err = None
    for attempt in range(retries):
        try:
            r = SESSION.get(WIKI_API, params=params, timeout=30)
            # Retry on throttling or transient upstream errors
            if r.status_code in (403, 429, 502, 503, 504):
                last_err = requests.HTTPError(f"HTTP {r.status_code}")
                time.sleep(backoff)
                backoff = min(backoff * 2, 16)
                continue
            r.raise_for_status()
            return r.json()
        except requests.RequestException as e:
            last_err = e
            time.sleep(backoff)
            backoff = min(backoff * 2, 16)
            continue
    # If we exhausted retries, raise the last seen error
    if last_err:
        raise last_err
    raise RuntimeError("wiki_api failed without an exception")

def fetch_category_members(cat_title, limit=5000):
    members, cmcontinue = [], None
    while True:
        params = {
            "action":"query","list":"categorymembers",
            "cmtitle":cat_title,"cmlimit":"500","cmtype":"page",
        }
        if cmcontinue: params["cmcontinue"] = cmcontinue
        data = wiki_api(params)
        members += [m["title"] for m in data.get("query",{}).get("categorymembers",[])]
        cmcontinue = data.get("continue",{}).get("cmcontinue")
        if not cmcontinue or len(members)>=limit: break
        time.sleep(0.2)
    return members

# naive link extraction from a page via parse API (grabs section links)
def fetch_pagelinks(page_title):
    data = wiki_api({"action":"parse","page":page_title,"prop":"links"})
    links = data.get("parse",{}).get("links",[])
    # keep only mainspace links
    out = []
    for l in links:
        if l.get("ns") == 0 and not l.get("exists") == False:
            title = l.get("title") or l.get("*")
            if title:
                out.append(title)
    return out

TITLE_BAD_WORDS = re.compile(r"\b(list|comparison|history|fictional|company|software|brand|protocol|standard|trade|trademark)\b", re.I)
CAPS_NOISE = re.compile(r"\s*\(.*?\)")

VERB_ROTATION = {
    "robotics": ["Design","Model","Specify","Create","Describe","Define"],
    "medical":  ["Design","Model","Define","Specify","Create","Describe"],
    "smarthome":["Model","Design","Define","Specify","Create","Describe"],
    "energy":   ["Design","Model","Define","Specify","Create","Describe"],
    "sensing":  ["Design","Model","Define","Specify","Create","Describe"],
    "aerospace":["Design","Model","Define","Specify","Create","Describe"],
    "generic":  ["Design","Model","Define","Specify","Create","Describe"],
}

def clean_title(t):
    t = CAPS_NOISE.sub("", t).strip()
    # Remove leading 'The', 'A', 'An'
    t = re.sub(r"^(The|A|An)\s+", "", t, flags=re.I)
    return t

def looks_like_device_or_system(title):
    # Heuristic: reject obvious meta pages
    if TITLE_BAD_WORDS.search(title): return False
    # reject people, places (very rough: commas or years)
    if re.search(r"\d{4}", title): return False
    if "," in title: return False
    return True

def to_prompt(title, domain):
    # very high-level, one sentence, no specifics
    v = VERB_ROTATION.get(domain, VERB_ROTATION["generic"])
    verb = v[hash(title) % len(v)]
    # generic rewordings to avoid bare nouns
    if re.search(r"\bsensor\b", title, re.I):
        return f"{verb} a sensing unit that measures the relevant quantity using a {title}."
    if re.search(r"\bpump\b", title, re.I) or re.search(r"pump$", title, re.I):
        return f"{verb} a pumping subsystem that moves fluid using a {title}."
    if re.search(r"\brobot\b", title, re.I):
        return f"{verb} a robotic system that performs its primary task using a {title}."
    # fallback
    return f"{verb} a system based on a {title} and describe its primary function at a high level."

def dedupe_stable(strings):
    seen, out = set(), []
    for s in strings:
        key = s.lower()
        if key in seen: continue
        seen.add(key); out.append(s)
    return out

# ---- 3) Harvest ----
def harvest():
    rows = []
    # categories
    for src in CATEGORY_SOURCES:
        titles = fetch_category_members(src["title"])
        for t in titles:
            t2 = clean_title(t)
            if looks_like_device_or_system(t2):
                rows.append({"title": t2, "domain": src["domain"]})
    # pages/lists
    for src in PAGE_SOURCES:
        links = fetch_pagelinks(src["title"])
        for t in links:
            t2 = clean_title(t)
            if looks_like_device_or_system(t2):
                rows.append({"title": t2, "domain": src["domain"]})
    # de-duplicate by title
    uniq = {}
    for r in rows:
        uniq.setdefault(r["title"].lower(), r)
    rows = list(uniq.values())
    # make prompts
    out = []
    for i, r in enumerate(rows, 1):
        desc = to_prompt(r["title"], r["domain"])
        # enforce short, high-level style
        desc = re.sub(r"\s+", " ", desc).strip()
        if 10 <= len(desc.split()) <= 28:
            out.append({
                "id": f"U{i}",
                "description": desc,
                "source_title": r["title"],
                "domain": r["domain"],
                "provenance": "wikipedia-harvest"
            })
    return out

if __name__ == "__main__":
    data = harvest()
    data = sorted(data, key=lambda x: hash(x["source_title"]))
    # Write files
    with open("sysml_targets.jsonl", "w", encoding="utf-8") as f:
        for r in data:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    with open("sysml_targets.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["id","description","domain","source_title","provenance"])
        for r in data:
            w.writerow([r["id"], r["description"], r["domain"], r["source_title"], r["provenance"]])
    print(f"Wrote {len(data)} items to sysml_targets.jsonl and sysml_targets.csv")
