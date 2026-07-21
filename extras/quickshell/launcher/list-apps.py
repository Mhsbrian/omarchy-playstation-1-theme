#!/usr/bin/env python3
# Emit a JSON array of launchable desktop apps: [{id, name, icon, comment}]
# deduped by desktop-id (user overrides system), sorted by name.
import json, os, glob

dirs = [
    os.path.expanduser("~/.local/share/applications"),
    "/usr/share/applications",
    "/var/lib/flatpak/exports/share/applications",
    os.path.expanduser("~/.local/share/flatpak/exports/share/applications"),
]

def parse(path):
    entry, in_main = {}, False
    try:
        with open(path, encoding="utf-8", errors="ignore") as f:
            for line in f:
                line = line.strip()
                if line.startswith("["):
                    in_main = (line == "[Desktop Entry]")
                    continue
                if not in_main or "=" not in line:
                    continue
                k, _, v = line.partition("=")
                entry[k.strip()] = v.strip()
    except OSError:
        return None
    if entry.get("Type") != "Application":
        return None
    if entry.get("NoDisplay", "").lower() == "true":
        return None
    if entry.get("Hidden", "").lower() == "true":
        return None
    name = entry.get("Name")
    if not name:
        return None
    return {
        "id": os.path.basename(path)[:-8],   # strip .desktop
        "name": name,
        "icon": entry.get("Icon", ""),
        "comment": entry.get("GenericName") or entry.get("Comment", ""),
    }

seen, apps = set(), []
for d in dirs:
    for path in sorted(glob.glob(os.path.join(d, "*.desktop"))):
        did = os.path.basename(path)[:-8]
        if did in seen:
            continue
        app = parse(path)
        if app:
            seen.add(did)
            apps.append(app)

apps.sort(key=lambda a: a["name"].lower())
print(json.dumps(apps))
