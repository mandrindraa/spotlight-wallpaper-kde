#!/usr/bin/env fish
# ─────────────────────────────────────────────────────────────────────────────
# spotlight-wallpaper.fish
# Downloads Windows Spotlight images (via Peapix public API) and sets them
# as the KDE Plasma desktop wallpaper.  Works offline by falling back to the
# local cache.
#
# Install:  cp spotlight-wallpaper.fish ~/.local/bin/
#           chmod +x ~/.local/bin/spotlight-wallpaper.fish
# ─────────────────────────────────────────────────────────────────────────────

# ── Config ────────────────────────────────────────────────────────────────────
set CACHE_DIR   "$HOME/.local/share/spotlight-wallpapers"
set STATE_FILE  "$HOME/.local/share/spotlight-wallpapers/.state"   # last-used filename
set API_URL     "https://peapix.com/spotlight/feed?n=8"
set MAX_CACHED  30          # keep at most this many images; oldest deleted first
set LOG_PREFIX  "[spotlight]"

# ── Helpers ───────────────────────────────────────────────────────────────────
function log
    echo "$LOG_PREFIX $argv" >&2
end

function internet_available
    # Quick DNS check – no full download needed
    curl -sf --max-time 5 --head "https://peapix.com" >/dev/null 2>&1
end

function set_wallpaper
    set img $argv[1]
    if test -f "$img"
        plasma-apply-wallpaperimage "$img" >/dev/null 2>&1
        and log "Wallpaper set → $(basename $img)"
        or log "WARNING: plasma-apply-wallpaperimage failed for $img"
    else
        log "ERROR: image file not found: $img"
    end
end

function pick_random_cached
    set files (ls -t "$CACHE_DIR"/*.jpg 2>/dev/null)
    set count (count $files)
    if test $count -eq 0
        return 1
    end
    set idx (math (random) % $count + 1)
    echo $files[$idx]
end

function evict_old_images
    set files (ls -t "$CACHE_DIR"/*.jpg 2>/dev/null)
    set count (count $files)
    if test $count -gt $MAX_CACHED
        set surplus (math $count - $MAX_CACHED)
        for i in (seq 1 $surplus)
            set victim $files[(math $count - $i + 1)]
            log "Evicting old image: $(basename $victim)"
            rm -f "$victim"
        end
    end
end

# ── Main ──────────────────────────────────────────────────────────────────────
mkdir -p "$CACHE_DIR"

if internet_available
    log "Online – fetching Spotlight feed…"

    set api_response (curl -sf --max-time 15 \
        -A "Mozilla/5.0 (X11; Linux x86_64)" \
        "$API_URL" 2>/dev/null)

    if test -z "$api_response"
        log "WARNING: empty API response, falling back to cache"
        set use_cache true
    else
        # Parse the JSON array with python (always available on CachyOS)
        set urls (echo $api_response | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data:
    url = item.get('fullUrl','')
    if url:
        print(url)
" 2>/dev/null)

        if test (count $urls) -eq 0
            log "WARNING: no URLs parsed from API, falling back to cache"
            set use_cache true
        else
            # Download any images we don't already have
            set newly_downloaded ""
            for url in $urls
                # Use the last path segment (hex hash) as filename
                set fname (string replace -ra '.*/' '' $url | string replace -ra '[^a-zA-Z0-9_.]' '_')
                set fname (string replace -r '_jpg.*' '.jpg' $fname)
                set dest "$CACHE_DIR/$fname"
                if not test -f "$dest"
                    log "Downloading: $fname"
                    curl -sf --max-time 30 -L -o "$dest" "$url" 2>/dev/null
                    if test $status -eq 0
                        set newly_downloaded $newly_downloaded $dest
                    else
                        log "WARNING: download failed for $url"
                        rm -f "$dest"
                    end
                end
            end

            evict_old_images

            # Prefer a freshly downloaded image; fall back to any cached one
            if test (count $newly_downloaded) -gt 0
                set chosen $newly_downloaded[1]
            else
                set chosen (pick_random_cached)
            end

            if test -n "$chosen"
                set_wallpaper "$chosen"
                echo (basename $chosen) >"$STATE_FILE"
            else
                log "ERROR: nothing to display"
                exit 1
            end
        end
    end
else
    log "Offline – using cached images"
    set use_cache true
end

# ── Offline / fallback path ───────────────────────────────────────────────────
if set -q use_cache
    set chosen (pick_random_cached)
    if test -n "$chosen"
        set_wallpaper "$chosen"
        echo (basename $chosen) >"$STATE_FILE"
    else
        log "ERROR: no cached images available and offline – nothing to do"
        exit 1
    end
end
