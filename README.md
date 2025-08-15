# watchdom

**Intelligent Domain Availability Monitoring with Phase-Aware Polling**

watchdom is a professional command-line tool for monitoring domain availability with smart interval adjustment, extensible TLD support, and automated notifications. Built following BashFX architectural principles for reliability and maintainability.

## 🎯 Core Concepts

### **Phase-Aware Polling System**

watchdom automatically adjusts its polling behavior based on proximity to your target time:

| Phase | When | Interval | Visual | Description |
|-------|------|----------|--------|-------------|
| **PRE** | >30min before target | Base interval (60s) | 🔵 λ `[PRE]` | Conservative monitoring |
| **HEAT** | ≤30min before target | Ramps 30s → 10s | 🔴 ▲ `[HEAT]` | Aggressive monitoring |
| **GRACE** | 0-3hrs after target | Sticks at 10s | 🟣 △ `[GRACE]` | High-frequency watch |
| **COOL** | >3hrs after target | 30s → 1hr progressive | 🔵 ❄ `[COOL]` | Resource-conscious cooldown |

### **Extensible TLD Support**

- **Built-in**: `.com`, `.net`, `.org` via Verisign/PIR
- **User-configurable**: Add any TLD via `~/.watchdomrc` or CLI commands
- **Pattern matching**: Flexible regex patterns for "domain available" detection

### **Smart Resource Management**

- **Rate limiting**: Warns about aggressive intervals to prevent service abuse
- **Cooldown system**: Prevents indefinite fast polling after target time
- **Grace period prompts**: User intervention after extended monitoring

## 📦 Installation

### Quick Install
```bash
# Download and run from anywhere
./watchdom.sh example.com

# Install system-wide (recommended)
./watchdom.sh install
watchdom example.com  # Now available globally
```

### Installation Locations (XDG+ Compliant)
- **Script**: `~/.local/lib/fx/watchdom`
- **Symlink**: `~/.local/bin/watchdom`  
- **Config**: `~/.watchdomrc` (user TLD configurations)

## 🚀 Quick Start

```bash
# Basic domain monitoring
watchdom example.com

# Monitor with target deadline
watchdom example.com --until "2025-12-25 18:00:00 UTC"

# Custom polling interval
watchdom example.com -i 30

# Verbose monitoring with debug output
watchdom -d example.com

# Time countdown only (no domain checking)
watchdom time "2025-12-25 18:00:00 UTC"
```

## 📋 Command Reference

### **Core Commands**

| Command | Description | Example |
|---------|-------------|---------|
| `watch DOMAIN` | Monitor domain availability | `watchdom watch example.com` |
| `time DATETIME` | Standalone time countdown | `watchdom time "2025-12-25 18:00:00 UTC"` |
| `list_tlds` | Show supported TLD patterns | `watchdom list_tlds` |
| `add_tld TLD SERVER PATTERN` | Add custom TLD support | `watchdom add_tld .uk whois.nominet.uk "No such domain"` |
| `test_tld TLD DOMAIN` | Test TLD pattern accuracy | `watchdom test_tld .com test-domain.com` |

### **Installation Commands**

| Command | Description | Example |
|---------|-------------|---------|
| `install` | Install to `~/.local/lib/fx/` | `watchdom install` |
| `uninstall` | Remove installation | `watchdom uninstall` |
| `status` | Show installation status | `watchdom status` |

### **Standard Options**

| Option | Description | Default |
|--------|-------------|---------|
| `-d, --debug` | Enable informational messages | Off |
| `-t, --trace` | Enable verbose debugging | Off |
| `-q, --quiet` | Force quiet mode (errors only) | Off |
| `-f, --force` | Skip safety guards | Off |
| `-D, --dev` | Developer mode (implies -d -t) | Off |

### **Domain Monitoring Options**

| Option | Description | Default |
|--------|-------------|---------|
| `-i SECONDS` | Base polling interval | 60 |
| `-e REGEX` | Override expected pattern | Auto-detect |
| `-n COUNT` | Max checks before stopping | Unlimited |
| `--until DATETIME` | Target time for ramping | None |
| `--time_local` | Display local time only | UTC + Local |

## 💡 Usage Examples

### **Basic Monitoring**
```bash
# Simple availability check
watchdom example.com

# With custom interval
watchdom example.com -i 30

# Quiet mode (errors only)
watchdom -q example.com
```

### **Deadline-Based Monitoring**
```bash
# Monitor until specific time
watchdom example.com --until "2025-12-25 18:00:00 UTC"

# Using epoch timestamp
watchdom example.com --until 1735142400

# Local time display only
watchdom example.com --until "2025-12-25 18:00:00 UTC" --time_local
```

### **Debug and Development**
```bash
# Verbose output for troubleshooting
watchdom -d example.com

# Full trace mode
watchdom -t example.com

# Developer mode with all debugging
watchdom -D example.com
```

### **TLD Management**
```bash
# See all supported TLDs
watchdom list_tlds

# Add new TLD support
watchdom add_tld .de whois.denic.de "Status: free"

# Test TLD pattern
watchdom test_tld .de test-domain.de

# Force override existing TLD
watchdom -f add_tld .com custom-whois.com "Custom pattern"
```

### **Custom Pattern Matching**
```bash
# Override detection pattern
watchdom example.com -e "Domain not found"

# Monitor with custom server and pattern
watchdom add_tld .custom whois.custom.tld "Available for registration"
watchdom example.com.custom
```

### **Time Utilities**
```bash
# Countdown to deadline (no domain monitoring)
watchdom time "2025-12-25 18:00:00 UTC"

# Local time display
watchdom time "2025-12-25 18:00:00 UTC" --time_local

# Using different time formats
watchdom time 1735142400
watchdom time "Dec 25 2025 6:00 PM UTC"
```

## 📧 Email Notifications

Enable automated alerts by setting all required environment variables:

```bash
export NOTIFY_EMAIL="user@domain.com"
export NOTIFY_FROM="watchdom@server.com"  
export NOTIFY_SMTP_HOST="smtp.gmail.com"
export NOTIFY_SMTP_PORT="587"
export NOTIFY_SMTP_USER="username"
export NOTIFY_SMTP_PASS="app_password"

# Now monitoring will send emails for:
# - Domain becomes available
# - Target time reached
# - Grace period exceeded (3+ hours)
```

**Supported Email Backends** (automatic fallback):
1. **mutt** (preferred)
2. **msmtp + mail** 
3. **sendmail**

## 🔧 Configuration

### **User TLD Configuration** (`~/.watchdomrc`)
```bash
# Format: TLD|WHOIS_SERVER|AVAILABLE_PATTERN
.uk|whois.nominet.uk|No such domain
.de|whois.denic.de|Status: free
.fr|whois.afnic.fr|No entries found
.io|whois.nic.io|is available for purchase
```

### **Environment Overrides**
```bash
# Customize defaults
export WATCHDOM_INTERVAL=30      # Default polling interval
export WATCHDOM_MAX_CHECKS=100   # Default max checks
export WATCHDOM_TIME_LOCAL=1     # Default to local time display
```

## 🎨 Visual Features

### **Phase Indicators**
- **🔵 λ [PRE]**: Blue lambda - pre-target conservative polling
- **🔴 ▲ [HEAT]**: Red triangle - approaching target, ramping up
- **🟣 △ [GRACE]**: Purple triangle - past target, grace period
- **🔵 ❄ [COOL]**: Cyan snowflake - cooling down after grace

### **Real-time Countdown**
```
🔴▲ next poll in 10s | target in 5m 23s | [HEAT] UTC: Wed Dec 25 18:00:00 UTC 2025
```

### **Status Messages**
- ✅ **SUCCESS**: Domain becomes available
- ⚠️ **WARNING**: Rate limiting or configuration issues  
- ❌ **ERROR**: Recoverable problems
- 💀 **FATAL**: Unrecoverable errors (exits)

## 📊 Exit Codes

| Code | Meaning | Description |
|------|---------|-------------|
| **0** | Success | Domain became available |
| **1** | Not found | Max checks reached without success |
| **2** | Bad arguments | Invalid command line options |
| **3** | Missing dependencies | Required commands not found |
| **4** | Date parse error | Invalid datetime format |
| **130** | User interrupt | Ctrl-C pressed |

## 🛡️ Safety Features

### **Rate Limiting Protection**
- Warns when intervals <10s may trigger server blocks
- Progressive cooldown prevents indefinite aggressive polling
- Configurable maximum check limits

### **Graceful Shutdown**
- Ctrl-C cleanup removes temporary files
- Email notifications for interrupted monitoring
- Preserves user configuration during uninstall

### **Input Validation**
- Domain format checking
- TLD configuration validation  
- Safe handling of user patterns and server names

## 🏗️ Architecture

Built following **BashFX** architectural principles:

- **Self-contained**: Uses only standard Unix tools
- **Rewindable**: Clean install/uninstall cycle
- **XDG+ compliant**: Respects filesystem conventions
- **Function ordinality**: Clear separation of concerns
- **QUIET compliance**: Hierarchical message levels

## 🐛 Troubleshooting

### **Common Issues**

**"TLD not supported"**
```bash
# Add support for new TLD
watchdom add_tld .example whois.example.com "Not found"
```

**"Whois command not found"**
```bash
# Install whois on your system
sudo apt install whois        # Debian/Ubuntu
sudo yum install whois        # RHEL/CentOS
brew install whois            # macOS
```

**"Email notifications not working"**
```bash
# Check all variables are set
watchdom status

# Test email configuration
echo "test" | mutt -s "test" your@email.com
```

**"Pattern not matching"**
```bash
# Test your TLD pattern
watchdom test_tld .com test-domain.com

# Use custom pattern
watchdom example.com -e "Custom available pattern"
```

### **Debug Mode**
```bash
# Enable verbose logging
watchdom -d example.com

# Full trace output
watchdom -t example.com

# Check installation
watchdom status
```

## 📝 Examples by Use Case

### **Domain Investor**
```bash
# Monitor premium domain drop
watchdom premium-domain.com --until "2025-12-25 18:00:00 UTC" -i 15

# Batch monitoring setup
echo "export NOTIFY_EMAIL=investor@example.com" >> ~/.bashrc
watchdom install
```

### **Brand Protection**
```bash
# Add international TLD support
watchdom add_tld .de whois.denic.de "Status: free"
watchdom add_tld .uk whois.nominet.uk "No such domain"

# Monitor brand variations
watchdom mybrand.de --until "2025-12-25 18:00:00 UTC"
```

### **Developer Waiting for Project Domain**
```bash
# Casual monitoring with notifications
watchdom myproject.com -i 300  # 5-minute intervals

# Time-only countdown to deadline
watchdom time "2025-12-25 18:00:00 UTC"
```

---

**Version**: 2.0.0-bashfx  
**Dependencies**: bash, whois, date, grep, sed  
**License**: Open source  
**Compatibility**: Linux, macOS, BSD systems