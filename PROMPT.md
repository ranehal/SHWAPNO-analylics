You are building a price-monitor dashboard from a mobile-app HAR capture. Follow this blueprint exactly.

---

## Phase 1 — HAR Reconnaissance

1. **Understand the HAR**: It's a 50+ MB JSON file captured from an Android app (com.app.android). Use the app version from `log.creator.comment`. Key sections: `log.entries[]` each with `request.url`, `request.method`, `request.postData`, `response.content.text` (often gzipped base64).

2. **Map API structure**: Collect all unique API URLs. Look for patterns:
   - Catalog root endpoint (e.g., `/Catalog/GetCatalogRoot`) — returns full category tree
   - Category products endpoint (e.g., `/Catalog/GetCategoryProducts/{id}`) — paginated POST with JSON body
   - Product details endpoint (e.g., `/Product/GetProductDetails/{id}`)
   - Any search or filter endpoints

3. **Extract auth**: Find `authorization` header or token values across requests. Usually a static bearer token or API key shared across all calls.

4. **Decode responses**: The HAR stores response bodies base64-encoded, often gzipped. Use `base64.b64decode` then `gzip.decompress` then `json.loads`.

5. **Build a manifest JS file** (`storename_manifest.js`): Extract category tree (id, name, sub_categories), API base URL, endpoints as function templates, total product count, and date range. The manifest is consumed by the frontend.

6. **Understand pagination**: The products endpoint is POST with a JSON body containing `PageNumber`, `PageSize`, and various filter fields (often dummy/null values that the API ignores). `TotalPages` comes back in `paging_filtering_model.total_pages`.

---

## Phase 2 — Scraper (Python)

Write `scraper.py` with these patterns:

```python
import json, re, os, sys, time, urllib.request, urllib.error, gzip, ssl
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed
from threading import Lock

API = 'https://api.example.com/api-frontend'
TOKEN = 'extracted-token'
HEADERS = {
    'authorization': TOKEN, 'accept': 'application/json',
    'content-type': 'application/json-patch+json', 'accept-encoding': 'gzip'
}
SSL_CTX = ssl.create_default_context()
SSL_CTX.check_hostname = False
SSL_CTX.verify_mode = ssl.CERT_NONE

def parse_price(pp, key):
    """Extract numeric price from strings like 'Tk 759' or 'USD 12.99'"""
    v = pp.get(key)
    if not v: return None
    s = str(v).replace(',', '').strip()
    m = re.search(r'[\d.]+', s)
    return float(m.group()) if m else None

def req(path, data=None):
    """Generic API caller with gzip handling"""
    h = {**HEADERS, 'user-agent': 'okhttp/4.9.3'}
    body = json.dumps(data).encode() if data else None
    r = urllib.request.Request(API + path, data=body, headers=h, method='POST' if data else 'GET')
    with urllib.request.urlopen(r, timeout=20, context=SSL_CTX) as resp:
        raw = resp.read()
        if resp.headers.get('Content-Encoding') == 'gzip' or raw[:2] == b'\x1f\x8b':
            raw = gzip.decompress(raw)
        return json.loads(raw.decode('utf-8'))
```

Key patterns:
- **Catalog root**: Returns array of top categories, each with `sub_categories[]` (1 level deep). Flatten into leaf-only list for scraping.
- **Leaf-only scraping**: Only scrape subcategories (leaf nodes), not parent aggregates. Each product gets tagged with `category` (subcategory name) and `category_path` (parent > child).
- **Pagination loop**: `while page <= min(total_pages, MAX_PAGES)` with PageSize=20. POST the same payload body each time, incrementing `PageNumber`.
- **Price parsing**: Prices come as formatted strings like `"Tk 759"`. Use `parse_price()` to extract numeric value and `old_price` may be `null`.
- **Unit normalization**: Parse product names with regex for weight/volume (`kg`, `gm`, `liter`, `ml`, `piece`). Compute `normalized_price` = price per standard unit.
- **Parallel scraping**: Use `ThreadPoolExecutor(max_workers=8)` and thread-safe `seen_ids` set with `Lock`. Each category is one future.
- **Dedup**: Products can appear in multiple categories (or parent + child). Track `seen_ids` to avoid duplicates; first-category-wins.
- **Output**: Save `storename_products.json` (full JSON) and `storename_data.js` (window.storename_data = [...] for direct browser loading).

Product schema:
```json
{
  "id": "st_{pid}",
  "name": "Product Name",
  "store": "storename",
  "category": "Subcategory Name",
  "category_path": "Parent > Subcategory",
  "unit": "SKU or pack size",
  "unit_type": "kg|liter|piece",
  "current_price": 759.0,
  "normalized_price": 759.0,
  "image": "https://cdn.example.com/image.jpg",
  "url": "",
  "first_seen": "2026-07-30",
  "old_price": 925.0,
  "discount_text": "18% OFF",
  "rating": 4.5,
  "sold": 9100
}
```

---

## Phase 3 — Frontend (HTML + JS + CSS)

The frontend is a single-page GroceryGOD-style price comparison dashboard. Strip it down to the target store only.

### index.html
- Remove all other store manifest `<script>` tags (keep only `storename_manifest.js` and `script.js`)
- Remove DuckDB-WASM importmap and module script (skip parquet loading)
- Page title: `"Store Name Price Monitor"`
- Search placeholder: `"Search StoreName products (Esc to close)..."`

### script.js — Key modifications from the original GroceryGOD:
1. **STORE_CONFIG**: Only the target store.
2. **Default filters**: `activeShopFilters = new Set(['storename'])`, `activeIntelFilter = 'all'` (NOT 'low' — that requires hist_count >= 1 which JSON data lacks).
3. **Init**: Skip `loadAllFromParquet()`, call `loadAllFromJson()` directly.
4. **loadAllFromJson()**: Preserve `category_path`, extract `category_parent` by splitting on ` > `.
5. **On load**: After `processData()`, populate `activeCategories` with ALL category IDs so everything shows by default.
6. **renderProducts()**: Remove the `activeShopFilters` check (only one store, always active).

### Sidebar hierarchy (renderSidebar):
- **Shop header** = "Select All" checkbox. Shows checked/indeterminate based on subcategory state. Clicking it toggles ALL subcategories.
- **Parent rows**: Each has its own checkbox that selects/deselects all its children. Has expand/collapse toggle (▶/▼).
- **Child rows**: Individual subcategory checkboxes. Toggling a child updates parent and shop checkbox states (checked/indeterminate).
- Use `parent-checkbox` class for parent row checkboxes (CSS: `width: 16px; height: 16px; accent-color: var(--accent-color)`).
- Category filter in `renderProducts()`: `activeCategories.has(p.store + '_' + p.category)`.

### Intelfilter behavior:
- Default: `'all'` — shows everything
- Click any filter button → toggles that filter on; click again → resets to `'all'`
- Add an "All" button to the intel bar for manual reset

### Stats bar:
- `updateStatsBar()` filters by the store only (not by `activeShopFilters`)
- Shows total filtered product count and "good buys" count (price < 95% of average)

---

## Phase 4 — Price Parsing Patterns

Prices from e-commerce APIs typically come in inconsistent formats:

| Format | Example | Parse Approach |
|--------|---------|---------------|
| Currency prefix | `"Tk 759"`, `"USD 12.99"` | Remove non-numeric chars except `.` |
| Plain string | `"759"` | Direct float conversion |
| Null/absence | `null` (old_price when no discount) | Return None |
| Comma separators | `"1,299"` | Strip commas first |
| Decimals | `"260.87"` | Standard float |
| Percentage off | `"18% OFF"` (discount_text, not price) | Store as string for display |

Always use `parse_price()` that handles all these cases. Never assume numeric fields exist.

---

## Phase 5 — Category Normalization

Product names often encode unit info:

```python
def parse_unit(name, price):
    t = name.lower()
    # Strip parenthetical size info like "(±500g)"
    t = re.sub(r'\(?[+\-\u00b1]\d+\s*(gm|g|kg|ml|ltr|l)?\)?', '', t)
    
    # Weight matches
    m = re.search(r'(\d+(\.\d+)?)\s*(kg|gm|gram|g)\b', t)
    if m:
        v = float(m.group(1))
        unit = m.group(3)
        if unit in ('gm', 'gram', 'g'):
            return 'kg', price / v * 1000  # normalize to kg
        else:
            return 'kg', price / v
    
    # Volume matches
    m = re.search(r'(\d+(\.\d+)?)\s*(ltr|liter|l|ml)\b', t)
    if m:
        v = float(m.group(1))
        if m.group(3) == 'ml':
            return 'liter', price / v * 1000  # normalize to liter
        else:
            return 'liter', price / v
    
    # Discrete units
    if any(x in t for x in ['pc','piece','hali','dozen','pkt','pack','each','bottle','can','box']):
        return 'piece', price
    
    return 'kg', price  # fallback
```

---

## Phase 6 — runall.bat Menu

Build a menu orchestrator with options:
- `[0]` Scrape All + Auto-Open Dashboard (chains scrape → serve → browser)
- `[1]` Start Frontend Server + Open Browser
- `[2]` Scrape API Live (parallel, subcategories)
- `[3]` Extract from HAR to JSON (offline fallback)
- `[4]` Show HAR Analysis Summary
- `[5]` Open Website + API in Browser
- `[Q]` Quit

---

## Final Structure

```
project/
├── scraper.py                 # Live API scraper (parallel, subcategory-aware)
├── extract_har.py             # Offline HAR extractor
├── runall.bat                 # Menu orchestrator
├── PROMPT.md                  # This file
├── frontend/
│   ├── index.html             # Store-only dashboard
│   ├── script.js              # Core engine (JSON fallback, hierarchical sidebar)
│   ├── style.css              # Dark theme + sidebar hierarchy styles
│   ├── storename_manifest.js  # Category tree + endpoint map
│   ├── storename_products.json # Scraped product data
│   └── storename_data.js      # window.storename_data for direct loading
└── *.har                      # Source HAR (delete after extraction)
```
