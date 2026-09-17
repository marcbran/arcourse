# arcourse Alfred workflow

Browse the arcourse graph from [Alfred](https://www.alfredapp.com/workflows/): list a
node's links, open any node in the web UI, or traverse deeper — all without leaving the
keyboard.

## Flow

Each window is **pinned to a single node** and lists only that node's links. The node
travels in the `node` workflow variable, not in the search box — so typing just filters.

1. Trigger with the keyword `arco` or the hotkey (**⌥Space** by default); the window opens
   pinned to `/root`. Rebind the hotkey by double-clicking the Hotkey object in Alfred's
   workflow editor.
2. The list shows every link of that node — the same set the web UI shows (nested internal
   neighbors plus the node's `links` field). **Type to fuzzy-filter** (`isue` → `issues`).
   If `fzf` is on `PATH` it ranks the matches (`fzf --filter`); otherwise a built-in fuzzy
   matcher is used. Each node's links are cached briefly so typing stays snappy.
3. **Enter** opens the target: an internal node opens its page in the arcourse web UI
   (`web_base_url` + query path); an external link opens its URL directly.
4. **Shift+Enter** enters the link as a new node — a fresh window pinned to it, showing its
   links. Repeat to walk the graph; **Enter** on any link opens it.
5. Once you've descended, an **⬆ Up** entry appears at the top. Shift+Enter on it goes back
   to the parent you came from (Enter opens the parent's page). It uses a breadcrumb of
   visited nodes, so it lands on the true parent whether the last hop was a constant
   (one path segment) or a variable (two: `name/value`).

`⌘C` copies the query path / URL of the highlighted item.

The node is carried two ways so it survives typing: Shift+Enter passes `node` into the
re-triggered Script Filter, and each run echoes `node` back in its output variables so
Alfred keeps it for the session.

## Requirements

- The `arco` CLI on `PATH` (or point the `arco_bin` variable at it).
- A reachable arcourse server. `arco` in `client` mode talks to it; `Enter` opens pages
  from `web_base_url`. Default is a local server on `http://localhost:1183`.
- `/usr/bin/python3` (ships with the Xcode Command Line Tools).

## Install

Import into Alfred either way:

- Double-click a built `arcourse.alfredworkflow` bundle, **or**
- copy this folder into `~/Library/Application Support/Alfred/Alfred.alfredpreferences/workflows/`.

Build a distributable bundle from this folder:

```sh
zip -r arcourse.alfredworkflow info.plist filter.py README.md
```

## Configuration

Set these in Alfred's workflow **Configuration** (or edit the `variables` in `info.plist`):

| Variable        | Default                 | Meaning                                     |
| --------------- | ----------------------- | ------------------------------------------- |
| `node`          | `/root`                 | Starting node path                          |
| `arco_bin`      | `arco`                  | Path to the `arco` binary                   |
| `fzf_bin`       | `fzf`                   | Path to `fzf` (optional; enables its ranking) |
| `web_base_url`  | `http://localhost:1183` | Base URL of the arcourse web UI             |
| `cache_seconds` | `5`                     | How long a node's link list is cached (0 = off) |

If `arco` (or `fzf`) is not on Alfred's `PATH`, set `arco_bin` / `fzf_bin` to the absolute
path (e.g. `/Users/you/go/bin/arco`). The script also probes `~/go/bin`,
`/opt/homebrew/bin`, and `/usr/local/bin` as a fallback. Filtering uses `fzf --filter` when
available and a built-in fuzzy matcher otherwise.

## How the link list is derived

`filter.py` runs `arco query <path> -f json -q` and reproduces the web UI's
`neighborItems` logic (`pkg/arcourse-ui/main.libsonnet`):

- recursive **internal neighbors**: any nested object carrying `_node` + `_queryPath`,
  labelled by its dotted key path;
- the node's **`links`** field: node refs (internal) and string values (external URLs);
- **`links` groups**: nested objects under `links`, flattened as `group: item`.
