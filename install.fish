#!/usr/bin/env fish
# ─────────────────────────────────────────────────────────────────────────────
# install.fish  –  one-shot installer for the Spotlight wallpaper system
# Run with:  fish install.fish
# ─────────────────────────────────────────────────────────────────────────────

set SCRIPT_DIR (dirname (realpath (status filename)))

echo "==> Installing spotlight-wallpaper.fish …"
mkdir -p ~/.local/bin
cp "$SCRIPT_DIR/spotlight-wallpaper.fish" ~/.local/bin/spotlight-wallpaper.fish
chmod +x ~/.local/bin/spotlight-wallpaper.fish

echo "==> Installing systemd user units …"
mkdir -p ~/.config/systemd/user
cp "$SCRIPT_DIR/spotlight-wallpaper.service" ~/.config/systemd/user/
cp "$SCRIPT_DIR/spotlight-wallpaper.timer"   ~/.config/systemd/user/

echo "==> Reloading systemd user daemon …"
systemctl --user daemon-reload

echo "==> Enabling and starting the timer …"
systemctl --user enable --now spotlight-wallpaper.timer

echo ""
echo "==> Running the script once right now …"
fish ~/.local/bin/spotlight-wallpaper.fish

echo ""
echo "✓ Done!  The wallpaper will refresh every hour."
echo "  Cache location : ~/.local/share/spotlight-wallpapers/"
echo "  View timer     : systemctl --user status spotlight-wallpaper.timer"
echo "  View logs      : journalctl --user -u spotlight-wallpaper.service -n 30"
echo "  Run manually   : fish ~/.local/bin/spotlight-wallpaper.fish"
