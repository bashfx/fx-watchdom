# watchdom

**Intelligent Domain Availability Monitoring with Phase-Aware Polling and a User-Friendly CLI**

`watchdom` is a professional, user-centric command-line tool for monitoring domain availability. It features smart, phase-aware polling that adjusts its frequency as a target time approaches, an extensible TLD system, and a robust, interactive user experience. Built following BashFX architectural principles for reliability and maintainability.

## ✨ Key Features

- **Phase-Aware Polling:** Automatically adjusts its polling frequency from a conservative base interval to an aggressive 10-second loop as your target time nears, and then gracefully cools down to conserve resources.
- **One-Time Queries:** Quickly check a domain's status with a single, non-polling query.
- **Extensible TLD Support:** Comes with built-in support for `.com`, `.net`, and `.org`, and allows users to easily add any other TLD via the command line or a simple configuration file.
- **Interactive Dependency Check:** Automatically detects if `whois` is not installed and interactively prompts the user to install it.
- **Rate Limit Detection:** Intelligently detects common rate-limiting messages from WHOIS servers and exits gracefully to prevent being blocked.
- **User-Friendly Prompts:** Features an "auto-yes" flag (`-y`/`--yes`) to streamline operation in automated scripts.
- **XDG+ Compliant:** Follows modern Linux filesystem standards for installation and configuration.

## 📦 Installation

First, make the script executable:
```bash
chmod +x watchdom_advanced.sh
```

Then, run the installer:
```bash
./watchdom_advanced.sh install
```
The script will be installed to `~/.local/lib/fx/watchdom` and a symlink will be created at `~/.local/bin/fx/watchdom`. The script will notify you if you need to add this directory to your system's `PATH`.

## 🚀 Quick Start

```bash
# Perform a single, immediate check for a domain
watchdom example.com

# Monitor a domain with a 10-second polling interval
watchdom example.com -i 10

# Monitor a domain until a specific drop time
watchdom example.com --until "2026-01-01 12:00:00 UTC"

# Add a new TLD and test it
watchdom add_tld .io whois.nic.io "is available for purchase"
watchdom test_tld .io my-new-app.io
```

## 📋 Command Reference

### **Core Commands**

| Command | Description | Example |
|---|---|---|
| `watch DOMAIN` | Monitor domain availability with polling. | `watchdom watch example.com -i 30` |
| `time DATETIME`| Standalone time countdown utility. | `watchdom time "2026-01-01 12:00:00"`|
| `list_tlds` | Show all supported TLD patterns. | `watchdom list_tlds` |
| `add_tld ...` | Add custom TLD support. | `watchdom add_tld .de whois.denic.de "Status: free"` |
| `test_tld ...` | Test a TLD's availability pattern. | `watchdom test_tld .de my-app.de` |

### **Installation Commands**

| Command | Description |
|---|---|
| `install` | Installs the script to `~/.local/lib/fx/`. |
| `uninstall`| Removes the script and its symlinks. |
| `status` | Shows the current installation status. |

### **Options**

| Option | Description |
|---|---|
| `-i, --interval SECS` | Base polling interval in seconds. (Default: 60) |
| `--until DATETIME` | Target time for dynamic interval ramping. |
| `-n, --max-checks N` | Stop after N checks if domain is not found. |
| `-y, --yes` | Automatically answer "yes" to all prompts. |
| `-d, --debug` | Enable detailed informational messages. |
| `-t, --trace` | Enable verbose function tracing. |
| `-f, --force` | Force actions like overwriting a TLD config. |