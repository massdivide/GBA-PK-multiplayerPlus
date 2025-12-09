#!/bin/bash
set -e

# GBA RadicalRed headless server setup script
# Tested on: Ubuntu 24.04 (should work on 22.04+)
# Run as your normal user with sudo rights:  ./gbasetup.sh

USER_NAME="${USER}"
HOME_DIR="/home/${USER_NAME}"
ROM_DIR="${HOME_DIR}/roms"
GBA_GO="${HOME_DIR}/gbago.sh"

echo "[GBA Setup] Starting setup as user: ${USER_NAME}"
echo "[GBA Setup] Home directory: ${HOME_DIR}"

# Basic sanity check
if [ "${USER_NAME}" = "root" ]; then
  echo "[GBA Setup] Please DO NOT run this as root. Run it as your normal user."
  exit 1
fi

echo "[GBA Setup] Updating package lists..."
sudo apt update

echo "[GBA Setup] Installing required packages..."
sudo apt install -y \
  mgba-qt \
  x11vnc \
  xvfb \
  screen \
  openbox

echo "[GBA Setup] Creating ROM directory at ${ROM_DIR} (if not exists)..."
mkdir -p "${ROM_DIR}"

echo
echo "================================================================================"
echo "[GBA Setup] IMPORTANT: Place your ROM file in:"
echo "    ${ROM_DIR}"
echo "and then update the ROM path inside ${GBA_GO} if needed."
echo "================================================================================"
echo

# Create VNC password if not already set
if [ ! -f "${HOME_DIR}/.vnc/passwd" ]; then
  echo "[GBA Setup] No VNC password found. Let's create one."
  echo "[GBA Setup] You will be prompted for a password (used when connecting via VNC)."
  x11vnc -storepasswd
else
  echo "[GBA Setup] VNC password already exists at ${HOME_DIR}/.vnc/passwd"
fi

echo "[GBA Setup] Writing gbago.sh to ${GBA_GO}..."

cat > "${GBA_GO}" << 'EOF'
#!/bin/bash

DISPLAY_NUM=":1"
SCREEN_GEOM="1280x720x24"
ROM="/home/customer/roms/RadicalServer.gba"   # <-- change this to your actual ROM path

start_services() {
    echo "[GBA Server] Starting services..."

    # Start Xvfb (screen session 'xvfb')
    if screen -list | grep -q "\.xvfb"; then
        echo "  - Xvfb screen session already running."
    else
        echo "  - Starting Xvfb in screen..."
        screen -S xvfb -dm Xvfb "$DISPLAY_NUM" -screen 0 "$SCREEN_GEOM"
        # wait for Xvfb to become ready
        sleep 2
    fi

    # Start Openbox window manager (screen session 'wm')
    if screen -list | grep -q "\.wm"; then
        echo "  - Window manager (Openbox) already running."
    else
        echo "  - Starting Openbox window manager in screen..."
        screen -S wm -dm bash -lc "export DISPLAY=$DISPLAY_NUM; openbox"
    fi

    # Start x11vnc (screen session 'vnc')
    if screen -list | grep -q "\.vnc"; then
        echo "  - x11vnc screen session already running."
    else
        echo "  - Starting x11vnc in screen..."
        # Uses display :1 and listens on TCP port 5901 (VNC :1)
        screen -S vnc -dm x11vnc -display "$DISPLAY_NUM" -rfbport 5901 -usepw -forever -shared -noxdamage
    fi

    # Start mGBA Qt (screen session 'mgba')
    if [ ! -f "$ROM" ]; then
        echo "  - ERROR: ROM not found at $ROM"
        exit 1
    fi

    if screen -list | grep -q "\.mgba"; then
        echo "  - mGBA screen session already running."
    else
        echo "  - Starting mGBA Qt in screen..."
        screen -S mgba -dm bash -lc "export DISPLAY=$DISPLAY_NUM; \
            export SDL_AUDIODRIVER=dummy; \
            export SDL_NOAUDIO=1; \
            export QT_XCB_FORCE_SOFTWARE_OPENGL=1; \
            /usr/games/mgba-qt '$ROM'"
    fi

    echo "[GBA Server] All services started. Connect with VNC on port 5901 (display :1)."
}

stop_services() {
    echo "[GBA Server] Stopping services..."

    # Stop mGBA screen + stray mgba-qt
    screen -S mgba -X quit 2>/dev/null && echo "  - Stopped mGBA screen." || echo "  - mGBA screen not running."
    pkill -x mgba-qt 2>/dev/null && echo "  - Killed stray mgba-qt." || true

    # Stop x11vnc screen + stray x11vnc
    screen -S vnc -X quit 2>/dev/null && echo "  - Stopped x11vnc screen." || echo "  - x11vnc screen not running."
    pkill -x x11vnc 2>/dev/null && echo "  - Killed stray x11vnc." || true

    # Stop Openbox WM
    screen -S wm -X quit 2>/dev/null && echo "  - Stopped Openbox window manager." || echo "  - Openbox (wm) not running."
    pkill -x openbox 2>/dev/null && echo "  - Killed stray openbox." || true

    # Stop Xvfb screen + stray Xvfb
    screen -S xvfb -X quit 2>/dev/null && echo "  - Stopped Xvfb screen." || echo "  - Xvfb screen not running."
    pkill -x Xvfb 2>/dev/null && echo "  - Killed stray Xvfb." || true

    echo "[GBA Server] All services stopped."
}

case "$1" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        stop_services
        sleep 1
        start_services
        ;;
    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
        ;;
esac
EOF

chmod +x "${GBA_GO}"

echo
echo "================================================================================"
echo "[GBA Setup] Done!"
echo
echo "Next steps:"
echo "  1) Copy your ROM to:  ${ROM_DIR}"
echo "       e.g.: scp RadicalServer.gba ${USER_NAME}@your-server:${ROM_DIR}/"
echo
echo "  2) If the ROM name/path differs, edit:"
echo "       ${GBA_GO}"
echo "     and change the ROM= line to your actual filename."
echo
echo "  3) Start the server stack with:"
echo "       ./gbago.sh start"
echo
echo "  4) From your PC, connect via VNC to:"
echo "       <server-ip>:5901"
echo "     You should see an Openbox desktop with mGBA Qt running."
echo
echo "  5) Stop everything with:"
echo "       ./gbago.sh stop"
echo "================================================================================"
echo
echo "[GBA Setup] All set, besto. <3"
