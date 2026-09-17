#!/usr/bin/env python3
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time


def resolve_bin(name, env_var):
    candidate = os.environ.get(env_var, "").strip() or name
    if os.path.sep in candidate:
        return candidate if os.path.exists(candidate) else None
    found = shutil.which(candidate)
    if found:
        return found
    home = os.environ.get("HOME", "")
    for extra in (
        os.path.join(home, "go", "bin"),
        "/opt/homebrew/bin",
        "/usr/local/bin",
    ):
        path = os.path.join(extra, candidate)
        if os.path.exists(path):
            return path
    return None


def web_base():
    return os.environ.get("web_base_url", "").strip().rstrip("/") or "http://localhost:1183"


def current_node():
    node = os.environ.get("node", "").strip() or "/root"
    if not node.startswith("/"):
        node = "/" + node
    return node


def is_node(value):
    return isinstance(value, dict) and "_node" in value and "_queryPath" in value


def collect_neighbors(obj, prefix="", exclude=(), link_strings=False):
    items = []
    for key in obj:
        if key in exclude or key.startswith("_"):
            continue
        value = obj[key]
        text = key if not prefix else "%s/%s" % (prefix, key)
        if is_node(value):
            items.append({"text": text, "link": value["_queryPath"], "external": False})
        elif isinstance(value, dict):
            items += collect_neighbors(value, text, exclude, link_strings)
        elif link_strings and isinstance(value, str):
            items.append({"text": text, "link": value, "external": True})
    return items


def links_items(obj):
    links = obj.get("links", {})
    if not isinstance(links, dict):
        return []
    out = []
    for key, value in links.items():
        if is_node(value):
            out.append({"text": key, "link": value["_queryPath"], "external": False})
        elif isinstance(value, str):
            out.append({"text": key, "link": value, "external": True})
    return out


def links_groups(obj):
    links = obj.get("links", {})
    if not isinstance(links, dict):
        return []
    groups = []
    for key, value in links.items():
        if isinstance(value, dict) and not is_node(value):
            groups.append({"title": key, "items": collect_neighbors(value, link_strings=True)})
    return groups


def node_links(obj):
    links = []
    seen = set()

    def add(text, link, external):
        key = (text, link)
        if key in seen:
            return
        seen.add(key)
        links.append({"text": text, "link": link, "external": external})

    for link in collect_neighbors(obj, "", ("data", "_view", "links"), False) + links_items(obj):
        add(link["text"], link["link"], link["external"])
    for group in links_groups(obj):
        for link in group["items"]:
            add("%s: %s" % (group["title"], link["text"]), link["link"], link["external"])
    return links


def cache_seconds():
    try:
        return int(os.environ.get("cache_seconds", "5"))
    except ValueError:
        return 5


def cache_path(node_path):
    cache_dir = os.environ.get("alfred_workflow_cache", "").strip()
    if not cache_dir:
        return None
    digest = hashlib.sha1(node_path.encode("utf-8")).hexdigest()
    return os.path.join(cache_dir, "node-%s.json" % digest)


def load_links(node_path):
    ttl = cache_seconds()
    path = cache_path(node_path)
    if path and ttl > 0 and os.path.exists(path):
        try:
            if time.time() - os.path.getmtime(path) < ttl:
                with open(path, "r") as fh:
                    return json.load(fh), None
        except (OSError, ValueError):
            pass

    arco = resolve_bin("arco", "arco_bin")
    if arco is None:
        return None, "arco not found — set the 'arco_bin' workflow variable"
    proc = subprocess.run(
        [arco, "query", node_path, "-f", "json", "-q"],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        return None, (proc.stderr or proc.stdout).strip()[:200] or "arco query returned an error"
    try:
        node = json.loads(proc.stdout or "{}")
    except json.JSONDecodeError:
        node = {}
    links = node_links(node)

    if path and ttl > 0:
        try:
            with open(path, "w") as fh:
                json.dump(links, fh)
        except OSError:
            pass
    return links, None


def fuzzy_score(text, term):
    smart = any(c.isupper() for c in term)
    haystack = text if smart else text.lower()
    pos = 0
    gaps = 0
    first = None
    last = -1
    for c in term:
        idx = haystack.find(c, pos)
        if idx == -1:
            return None
        if first is None:
            first = idx
        if last >= 0:
            gaps += idx - last - 1
        last = idx
        pos = idx + 1
    return (gaps, first, len(text))


def fzf_filter(fzf, query, links):
    texts = [link["text"] for link in links]
    proc = subprocess.run(
        [fzf, "--filter", query],
        input="\n".join(texts),
        capture_output=True,
        text=True,
    )
    if proc.returncode not in (0, 1):
        return None
    by_text = {}
    for link in links:
        by_text.setdefault(link["text"], link)
    ordered = []
    for line in proc.stdout.split("\n"):
        if line in by_text:
            ordered.append(by_text[line])
    return ordered


def py_filter(query, links):
    terms = query.split()
    scored = []
    for link in links:
        total = (0, 0, 0)
        ok = True
        for term in terms:
            score = fuzzy_score(link["text"], term)
            if score is None:
                ok = False
                break
            total = tuple(a + b for a, b in zip(total, score))
        if ok:
            scored.append((total, link))
    scored.sort(key=lambda pair: pair[0])
    return [link for _, link in scored]


def filter_links(query, links):
    query = query.strip()
    if not query:
        return links
    fzf = resolve_bin("fzf", "fzf_bin")
    if fzf is not None:
        result = fzf_filter(fzf, query, links)
        if result is not None:
            return result
    return py_filter(query, links)


def alfred_item(text, link, external, base, push_stack):
    if external:
        return {
            "title": text,
            "subtitle": link,
            "arg": link,
            "mods": {"shift": {"valid": False, "subtitle": "External link — nothing to enter"}},
            "text": {"copy": link, "largetype": link},
            "icon": {"path": "external.png"},
        }
    return {
        "title": text,
        "subtitle": link,
        "arg": base + link,
        "mods": {"shift": {
            "valid": True,
            "arg": "",
            "subtitle": "↳ Enter %s" % text,
            "variables": {"node": link, "stack": push_stack},
        }},
        "text": {"copy": link, "largetype": link},
        "icon": {"path": "node.png"},
    }


def up_item(parent, new_stack, base):
    return {
        "title": "⬆ Up",
        "subtitle": parent,
        "arg": base + parent,
        "mods": {"shift": {
            "valid": True,
            "arg": "",
            "subtitle": "↳ Go up to %s" % parent,
            "variables": {"node": parent, "stack": json.dumps(new_stack)},
        }},
        "text": {"copy": parent, "largetype": parent},
        "icon": {"path": "up.png"},
    }


def load_stack():
    try:
        stack = json.loads(os.environ.get("stack", "[]"))
    except ValueError:
        return []
    return stack if isinstance(stack, list) else []


def emit(node_path, stack, items):
    print(json.dumps({"variables": {"node": node_path, "stack": json.dumps(stack)}, "items": items}))


def main():
    node_path = current_node()
    query = sys.argv[1] if len(sys.argv) > 1 else ""
    stack = load_stack()

    links, err = load_links(node_path)
    if err is not None:
        emit(node_path, stack, [{"title": "Query failed: %s" % node_path, "subtitle": err, "valid": False}])
        return

    base = web_base()
    matched = filter_links(query, links)
    push_stack = json.dumps(stack + [node_path])
    items = [alfred_item(link["text"], link["link"], link["external"], base, push_stack) for link in matched]

    if not matched:
        if links:
            items = [{"title": "No match for “%s”" % query.strip(), "subtitle": node_path, "valid": False}]
        elif not stack:
            items = [{
                "title": "No links from %s" % node_path,
                "subtitle": "%s%s" % (base, node_path),
                "arg": base + node_path,
                "valid": True,
            }]

    if stack and not query.strip():
        items.insert(0, up_item(stack[-1], stack[:-1], base))

    emit(node_path, stack, items)


if __name__ == "__main__":
    main()
