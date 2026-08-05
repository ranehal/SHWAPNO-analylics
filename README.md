# 🛒 Shwapno Price Monitor Dashboard

> **Real-Time Price Monitoring, Top Movers Scorecards & Catalog Telemetry Suite for Shwapno Superstore Online.**

[![Live Demo](https://img.shields.io/badge/Live%20Demo-GitHub%20Pages-0099ff?style=for-the-badge&logo=github)](https://ranehal.github.io/swapnoTRACKER/)
[![Python 3.9+](https://img.shields.io/badge/Python-3.9%2B-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://www.python.org/)
[![JavaScript ES6+](https://img.shields.io/badge/JavaScript-ES6%2B-F7DF1E?style=for-the-badge&logo=javascript&logoColor=black)](https://developer.mozilla.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

---

## 📌 Executive Summary

**Shwapno Price Monitor** is a market analytics and catalog tracking suite built for [Shwapno](https://www.shwapno.com) (`store-api.shwapno.com`), ACI Logistics' online superstore and Bangladesh's retail supermarket chain.

The platform continuously monitors catalog pricing, highlights daily top price movers and discount opportunities, indexes category trees, and presents historic price trends through an AMOLED dark-mode web dashboard hostable on GitHub Pages.

---

## 🚀 Key Features

- **🌐 Store API Integration**: Connects to `store-api.shwapno.com` backend endpoints discovered via HAR traffic extraction ([`extract_har.py`](file:///C:/PROJECTS/shopno/extract_har.py)).
- **🌳 Automated Category Discovery**: Recursively traverses megamenu trees ([`discover_cats.py`](file:///C:/PROJECTS/shopno/discover_cats.py)) to map top-level, sub-level, and leaf categories into [`shwapno_categories.json`](file:///C:/PROJECTS/shopno/shwapno_categories.json).
- **📉 Top Movers & Discount Scorecards**: Identifies maximum price drops, discount percentages, and category coverage metrics.
- **📱 AMOLED Dark Mode UI**: Clean, high-contrast black design system optimized for modern displays.
- **⚡ GitHub Pages Deployable**: Generates static JS manifest files ([`shwapno_manifest.js`](file:///C:/PROJECTS/shopno/shwapno_manifest.js)) for zero-server deployment.

---

## 🏗️ System Architecture

```mermaid
flowchart TD
    subgraph Discovery_Phase ["🔍 Category & API Discovery"]
        HAR[Reqable HAR Log Analysis] -->|extract_har.py| Endpoints[Discovered Shwapno APIs]
        Endpoints -->|discover_cats.py| Categories[shwapno_categories.json]
    end

    subgraph Scraper_Pipeline ["⚡ Ingestion Engine"]
        Categories --> Scraper[scraper.py Catalog Scraper]
        Scraper -->|Query store-api.shwapno.com| CatalogData[Product Price Telemetry]
    end

    subgraph Presentation_Layer ["📊 Presentation & Deployment"]
        CatalogData --> Manifest[shwapno_manifest.js Data Export]
        Manifest --> UI[frontend/ AMOLED Dark Mode SPA]
        UI -->|GitHub Actions| GHPages[GitHub Pages Deployment]
    end
```

---

## 📁 Repository Structure

```
shopno/
├── scraper.py              # Catalog API price scraper & ingestion engine
├── discover_cats.py        # Automatic category tree crawler & discovery script
├── analyze_cats.py         # Category stats & coverage analyzer
├── extract_har.py          # HAR network traffic extractor & payload parser
├── runall.bat              # Interactive Windows batch launcher (Scraper / Server / Both)
├── shwapno_categories.json # Discovered category hierarchy map
├── shwapno_manifest.js    # Compiled JavaScript dataset for static frontend
├── frontend/               # Web Dashboard Directory
│   ├── index.html          # Main application markup
│   ├── app.js              # Interactive UI, chart rendering & search engine
│   └── style.css           # Modern AMOLED dark mode design system
└── .github/workflows/      # Automated deployment workflows
```

---

## ⚡ Quick Start & Local Setup

### 1. Interactive Windows Launcher
Run [`runall.bat`](file:///C:/PROJECTS/shopno/runall.bat):
```cmd
runall.bat
```

### 2. Manual CLI Commands
```bash
# Discover latest category trees
python discover_cats.py

# Execute full catalog scraper
python scraper.py

# Start local dev server
python -m http.server 8765 -d frontend
```
Open `http://localhost:8765` in your web browser.

---

## 📜 License

Distributed under the MIT License. Trademarks and data belong to Shwapno / ACI Logistics. Built for educational and price analytics research.
