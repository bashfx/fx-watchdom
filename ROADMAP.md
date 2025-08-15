# `watchdom` Development Roadmap

This document outlines potential future features and improvements for the `watchdom` script. These are ideas to be considered for future development cycles.

### High-Priority Features

- **Multi-Domain Watching:**
    - Allow passing multiple domains to a single `watchdom` command to monitor them concurrently.
    - This would likely require significant changes to the polling loop, possibly managing child processes for each domain.

- **Advanced Output Formats:**
    - Add flags like `--json` or `--csv` to the `watch` and `test_tld` commands.
    - This would make the script's output easily parsable for integration with other tools and automated systems.

### Medium-Priority Features

- **Enhanced Dependency Management:**
    - Make the `_ensure_dependency` function more intelligent.
    - Detect the user's operating system and use the appropriate package manager (`yum` for RHEL/CentOS, `pacman` for Arch, `brew` for macOS, etc.) instead of assuming `apt-get`.

- **Configuration File for All Settings:**
    - Expand `~/.watchdomrc` to allow setting default values for any command-line option (e.g., default interval, default `--until` format).
    - Allow customization of the `RATE_LIMIT_PATTERN`.

- **Background / Daemon Mode:**
    - Add a `--daemon` or `--background` flag to make `watchdom` fork itself into the background, detach from the terminal, and log its output to a file (e.g., in `~/.cache/tmp/fx/watchdom/`).

### Low-Priority "Nice-to-Have" Features

- **Plugin System for TLDs:**
    - Instead of users manually adding TLDs, create a system where `watchdom` can update its TLD list from a central, community-maintained repository (e.g., a file on GitHub).
    - A command like `watchdom update-tlds` could fetch the latest definitions.

- **Sound Notifications:**
    - In addition to email, provide an option for a terminal bell or sound notification when a domain becomes available.

- **International Domain Name (IDN) Support:**
    - Add better handling and validation for non-ASCII domain names.
