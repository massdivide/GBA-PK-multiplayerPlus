#!/bin/bash

DISPLAY_NUM=":1"
SCREEN_GEOM="1280x720x24"
ROM="/home/user/roms/RadicalServer.gba"   # <-- change this if needed

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
