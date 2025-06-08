# Wine Prefix Cloning Utility - README

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

This script simplifies the process of cloning a pre-configured Wine prefix to new locations (including external drives) and optionally installing games/DLCs into the new prefix.

# Key Features:

    Clone a base Wine prefix to new locations

    Supports both internal and external storage

    GUI interface with KDE Plasma integration (terminal fallback)

    Optional game/DLC installation after cloning

    Progress tracking and user-friendly dialogs

# Prerequisites
1. Base Wine Prefix Setup

# Dependencies
* Debian/Ubuntu: ```sudo apt install wine winetricks rsync kdialog```

* Arch/Manjaro: ```sudo pacman -S wine winetricks rsync kdialog```

**You must create a properly configured base Wine prefix before using this script**

# Create base prefix directory
```mkdir -p ~/Games/BasePrefix```

# Initialize Wine prefix
```WINEPREFIX=~/Games/BasePrefix wineboot```

# Install essential dependencies (example)
```WINEPREFIX=~/Games/BasePrefix winetricks vcrun2019 dxvk corefonts```

    Important: Your base prefix should include:

        All necessary system dependencies (VC runtimes, .NET frameworks, etc.)

        Any required Wine configurations

        Game launchers (Steam, Epic Games Store, etc.) if needed

        DXVK/VKD3D if using Vulkan translation


# Configuration

**Edit these variables at the top of the script**

BASEPREFIX="$HOME/Games/BasePrefix"       # Path to your prepared base prefix

INTERNAL_PREFIX_ROOT="$HOME/Games"        # Default location for new prefixes

**Usage**
Make the script executable:

```chmod +x clone-prefix.sh```

Run the script:

    ./clone-prefix.sh

    Follow the prompts:

        Choose installation location (internal or external drive)

        Enter name for new prefix

        Optionally install games/DLCs after cloning

Process Workflow

    Location Selection:

        Choose between internal storage or external drives

        External drives are auto-detected from /run/media/$USER/

    Prefix Creation:

        New prefix name validation (alphanumeric + . - _)

        Existing prefix overwrite confirmation

        Uses rsync for efficient copying

    Game Installation:

        Optionally run EXE/MSI installers after cloning

        Multiple installers can be run sequentially

        Wine debug messages suppressed during installation

    Completion:

        Full path to new prefix displayed

        Ready to run games from new location



# FAQ

**Q: Why clone prefixes instead of creating new ones?**\
A: Cloning saves hours of configuration by preserving installed dependencies and settings.

**Q: Can I use this for different Wine versions?**\
A: Yes! The base prefix determines the Wine version - create multiple base prefixes for different versions.

**Q: Why use external drives?**\
A: Ideal for large game libraries or portable installations between machines.

**Q: How do I update the base prefix?**\
A: Modify your original base prefix, then new clones will include the updates.

**Q: Can I automate game installations?**\
A: Currently interactive only - future versions may support install scripts.
