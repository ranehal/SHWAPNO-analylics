@echo off
cd /d "%~dp0"
title Shwapno Price Monitor

:MENU
cls
echo ============================================
echo      SHWAPNO PRICE MONITOR DASHBOARD
echo ============================================
echo.
echo  [0] Scrape All + Auto-Open Dashboard
echo  [1] Start Frontend Server + Open Browser
echo  [2] Scrape API Live (parallel, subcategories)
echo  [3] Extract from HAR to JSON (offline fallback)
echo  [4] Show HAR Analysis Summary
echo  [5] Open Website + API in Browser
echo  [Q] Quit
echo.
set /p choice="Select option: "

if /I "%choice%"=="0" goto SCRAPE_SERVE
if /I "%choice%"=="1" goto SERVE
if /I "%choice%"=="2" goto SCRAPE
if /I "%choice%"=="3" goto EXTRACT
if /I "%choice%"=="4" goto ANALYSIS
if /I "%choice%"=="5" goto WEBSITES
if /I "%choice%"=="Q" goto QUIT
goto MENU

:SCRAPE_SERVE
echo.
echo === Scraping API... ===
python scraper.py
if %ERRORLEVEL% neq 0 (
    echo Scrape failed. Check errors above.
    pause
    goto MENU
)
echo.
echo === Starting server, then opening browser... ===
start /B python -m http.server 8765 -d frontend
timeout /t 2 /nobreak >nul
start "" "http://localhost:8765"
echo Server running at http://localhost:8765 — press Ctrl+C to stop.
pause
goto MENU

:SERVE
echo.
echo === Starting frontend server on http://localhost:8765 ===
start /B python -m http.server 8765 -d frontend
timeout /t 2 /nobreak >nul
start "" "http://localhost:8765"
echo Server running at http://localhost:8765 — press Ctrl+C to stop.
pause
goto MENU

:SCRAPE
echo.
echo === Scraping Shwapno API... ===
python scraper.py
if %ERRORLEVEL% neq 0 (
    echo Scrape failed. Check errors above.
)
pause
goto MENU

:EXTRACT
echo.
echo === Extracting from HAR file... ===
python extract_har.py
if %ERRORLEVEL% neq 0 (
    echo Extraction failed. Check errors above.
)
pause
goto MENU

:ANALYSIS
echo.
echo === HAR Analysis Summary ===
python -c "import json, os; from datetime import datetime; har = json.load(open('sopno dsu-a.shalltry.com_2026_07_30_04_21_11.har', encoding='utf-8')); e = har['log']['entries']; urls = set(entry['request']['url'] for entry in e if entry['response']['status'] == 200); cats = set(u for u in urls if '/en/api/' in u); print(f'Total entries: {len(e)}'); print(f'Unique API URLs: {len(cats)}'); data_sizes = [entry['response']['content'].get('size', 0) for entry in e]; print(f'Total data transferred: {sum(data_sizes)/1024/1024:.1f} MB'); times = [entry['startedDateTime'] for entry in e]; print(f'Capture start: {times[0]}'); print(f'Capture end: {times[-1]}'); t0 = datetime.fromisoformat(times[0].replace('Z','+00:00')); t1 = datetime.fromisoformat(times[-1].replace('Z','+00:00')); print(f'Duration: {(t1 - t0).seconds}s');"
pause
goto MENU

:WEBSITES
echo.
echo Opening Shwapno website and API...
start "" "https://www.shwapno.com"
start "" "https://store-api.shwapno.com/en/api"
timeout /t 2 >nul
goto MENU

:QUIT
echo.
echo Goodbye!
exit /b 0
