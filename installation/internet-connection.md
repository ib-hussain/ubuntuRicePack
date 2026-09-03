## Shell Script for Setting Up the TP‑Link TL‑WN725N on Another Ubuntu PC

Below is a ready‑to‑use script. It automates the following:

- Removes and blacklists outdated out‑of‑tree drivers (e.g., `r8188eu`, `8188eu`, `rtl8188eus`)
- Loads the built‑in `rtl8xxxu` driver
- Detects the new USB Wi‑Fi interface
- Connects to a specified Wi‑Fi network using `nmcli`

### Usage

Run the script with `sudo` and provide the Wi‑Fi SSID and password as arguments:

```bash
sudo ./setup_tlwn725n.sh "Your_SSID" "Your_Password"
```

If you omit the arguments, the script will prompt for them.

### The Script

Create a file, e.g., `setup_tlwn725n.sh`, and paste the following:

```bash
#!/bin/bash
# setup_tlwn725n.sh - Configure TP-Link TL-WN725N USB WiFi on Ubuntu (built-in rtl8xxxu driver)
# Usage: sudo ./setup_tlwn725n.sh [SSID] [PASSWORD]

set -e  # Exit on error

# Check for root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)."
    exit 1
fi

# Function to print messages
log() {
    echo -e "\n[$(date +'%H:%M:%S')] $1\n"
}

# Get SSID and password from arguments or prompt
if [ $# -ge 2 ]; then
    SSID="$1"
    PASSWORD="$2"
else
    read -p "Enter Wi-Fi SSID: " SSID
    read -s -p "Enter Wi-Fi password: " PASSWORD
    echo
fi

# --- 1. Remove conflicting drivers ---
log "Removing conflicting out-of-tree drivers (if loaded)..."
for mod in r8188eu 8188eu rtl8188eus; do
    if lsmod | grep -q "^$mod"; then
        echo "Unloading $mod"
        modprobe -r $mod || true
    fi
done

# --- 2. Blacklist conflicting drivers ---
BLACKLIST_FILE="/etc/modprobe.d/blacklist-rtl8188eu.conf"
if [ ! -f "$BLACKLIST_FILE" ]; then
    log "Blacklisting conflicting drivers..."
    cat > "$BLACKLIST_FILE" <<EOF
# Blacklist out-of-tree rtl8188eu drivers to use built-in rtl8xxxu
blacklist r8188eu
blacklist 8188eu
blacklist rtl8188eus
EOF
    echo "Created $BLACKLIST_FILE"
else
    echo "Blacklist file already exists. Skipping."
fi

# --- 3. Load the built-in driver ---
log "Loading built-in rtl8xxxu driver..."
modprobe rtl8xxxu || true

# --- 4. Wait for interface to appear ---
log "Waiting for wireless interface..."
sleep 3
# The new interface usually appears as wlx<MAC address> or wlanX
WIFI_IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(wlx|wlan)[0-9a-fA-F]*' | grep -v '^wlo' | head -n1)

if [ -z "$WIFI_IFACE" ]; then
    log "ERROR: No wireless interface detected. Is the USB adapter plugged in?"
    exit 1
fi

log "Detected wireless interface: $WIFI_IFACE"

# --- 5. Connect to Wi-Fi using nmcli ---
if command -v nmcli >/dev/null 2>&1; then
    log "Connecting to network '$SSID'..."
    # Delete any previous connection with same name to avoid conflicts (optional)
    nmcli con delete "$SSID" 2>/dev/null || true
    nmcli device wifi connect "$SSID" password "$PASSWORD" ifname "$WIFI_IFACE"
    log "Connection established."
else
    log "nmcli not found. Install network-manager or use wpa_supplicant manually."
    exit 1
fi

# --- 6. Verify internet connectivity ---
log "Testing internet connectivity..."
if ping -c 3 8.8.8.8 >/dev/null 2>&1; then
    log "Internet connection is working."
else
    log "Warning: Could not reach 8.8.8.8. Check your credentials or router."
fi

log "Setup complete."
```

### Explanation of Key Steps

1. **Remove conflicting drivers**  
   `r8188eu`, `8188eu`, and `rtl8188eus` are the most common out‑of‑tree drivers that conflict with the built‑in `rtl8xxxu`. Unloading them prevents conflicts.

2. **Blacklist them**  
   Creating a file in `/etc/modprobe.d/` ensures they never load automatically again, even after a reboot.

3. **Load `rtl8xxxu`**  
   The built‑in driver that supports your TL‑WN725N.

4. **Detect the new interface**  
   The USB adapter typically appears as `wlx` followed by the MAC address (e.g., `wlxc03a55ef990f`). The script searches for a wireless interface that is not the internal one (`wlo` is common for built‑in Intel cards).

5. **Connect using `nmcli`**  
   This is the standard NetworkManager command‑line tool. It creates a connection profile and activates it.

6. **Verify connectivity**  
   Pings Google’s DNS to confirm internet access.

### Making the Script Executable

```bash
chmod +x setup_tlwn725n.sh
```

### Running the Script on the Other PC

1. Copy the script to the target machine (e.g., via USB stick or using `scp`).
2. Plug in the TP‑Link USB adapter.
3. Run the script with `sudo`:
   ```bash
   sudo ./setup_tlwn725n.sh "Your_SSID" "Your_Password"
   ```
4. The script will automatically configure everything and connect to Wi‑Fi.

### Troubleshooting the Script

- If the script reports “No wireless interface detected”, unplug and replug the adapter, then run again.
- If `nmcli` is not found, install `network-manager`:
  ```bash
  sudo apt update && sudo apt install network-manager
  ```
- If you prefer a minimal setup without `nmcli`, you could use `wpa_supplicant`, but the above script assumes a standard Ubuntu desktop with NetworkManager installed.

---

Now your internal Wi‑Fi should be back, and you have a reusable script for any Ubuntu 26 machine with only Ethernet. Let me know if you need any further adjustments!