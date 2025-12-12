#!/usr/bin/env bash
# 
# Zsh and Oh My Zsh Automated Setup Script
# This script installs Zsh, the Oh My Zsh framework, and key plugins
# on Debian/Ubuntu, CentOS, and Rocky Linux systems.
#
# NOTE: Run this script with 'bash setup.sh'

# --- 1. CONFIGURATION VARIABLES ---

# The list of core, mandatory packages (required for Zsh installation and operation).
CORE_PACKAGES="zsh git curl neovim" 
QUIET_MODE=false # Global flag for quiet mode

# --- 2. OS & PACKAGE MANAGER DETECTION ---

detect_os() {
    # Check for the existence of /etc/os-release, which is standard on modern Linux.
    if [ -f /etc/os-release ]; then
        # Source the file to load distribution variables (ID, ID_LIKE, VERSION_ID)
        . /etc/os-release
        
        # Determine the distribution and set package manager variables
        case "$ID" in
            ubuntu|debian)
                OS_TYPE="Debian-based"
                PKG_MANAGER="apt"
                INSTALL_CMD="sudo apt install -y"
                # apt update needs to run before any installs
                ;;
            centos|rhel|rocky|almalinux)
                OS_TYPE="RHEL-based"
                # Use 'dnf' for modern RHEL/CentOS/Rocky (RHEL 8+)
                # DNF is generally preferred as 'yum' is often a symlink to 'dnf'
                PKG_MANAGER="dnf"
                INSTALL_CMD="sudo dnf install -y"
                ;;
            *)
                echo "Error: Unsupported distribution ($ID). This script only supports Ubuntu/Debian, CentOS, and Rocky Linux."
                exit 1
                ;;
        esac 
        echo "Detected OS: $NAME ($VERSION_ID). Using package manager: $PKG_MANAGER."
    else
        echo "Error: Could not find /etc/os-release. Cannot determine distribution."
        exit 1
    fi
}

# --- 3. PREREQUISITES CHECK AND INSTALLATION ---

install_prerequisites() {
    echo -e "\n--- Installing Core Packages ---"
    
    # 3.1. Install Mandatory Packages
    local mandatory_packages="$CORE_PACKAGES"
    local mandatory_missing=""

    # Update package lists first for APT
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        echo "Running sudo apt update..."
        if $QUIET_MODE; then
            sudo apt update > /dev/null 2>&1
        else
            sudo apt update
        fi
    fi
    
    for pkg in $mandatory_packages; do
        if ! command -v "$pkg" > /dev/null 2>&1; then
            mandatory_missing+="$pkg "
        fi
    done

    if [ -n "$mandatory_missing" ]; then
        echo "Installing mandatory packages: $mandatory_missing"
        if $QUIET_MODE; then
            # Execute the installation command silently
            $INSTALL_CMD $mandatory_missing > /dev/null 2>&1
        else
            # Execute the installation command verbosely
            $INSTALL_CMD $mandatory_missing
        fi
        
        if [ $? -ne 0 ]; then
            echo "Error: Failed to install one or more MANDATORY packages ($mandatory_missing). Aborting setup."
            exit 1
        fi
    fi
    echo "Mandatory packages (Zsh, Git, Curl, Neovim) installed or already present."

    # 3.2. Install Optional Packages (ripgrep, fzf, fastfetch, eza, fd, bat) - Skipping on failure
    echo -e "\n--- Installing Optional Utility Packages (ripgrep, fzf, fastfetch, eza, fd, bat) ---"
    local optional_packages="ripgrep fzf fastfetch eza"
    
    for pkg in $optional_packages; do
        if command -v "$pkg" > /dev/null 2>&1; then
            echo "$pkg is already installed. Skipping."
            continue
        fi

        echo "Attempting to install $pkg..."
        local install_status=0
        if $QUIET_MODE; then
            $INSTALL_CMD "$pkg" > /dev/null 2>&1
            install_status=$?
        else
            # We still suppress stderr here to avoid displaying expected package manager warnings
            $INSTALL_CMD "$pkg" 2>/dev/null 
            install_status=$?
        fi

        if [ $install_status -ne 0 ]; then
            echo "Warning: Failed to install optional package '$pkg' (Exit code: $install_status). This package will be skipped."
        else
            echo "$pkg installed successfully."
        fi
    done

    # --- Handle fd / fd-find specially ---
    if command -v "fd" > /dev/null 2>&1; then
        echo "fd is already installed. Skipping."
    else
        echo "Attempting to install 'fd' or 'fd-find'..."
        
        local install_status=0
        
        # Try 'fd' first
        if $QUIET_MODE; then
            $INSTALL_CMD "fd" > /dev/null 2>&1
            install_status=$?
        else
            $INSTALL_CMD "fd" 2>/dev/null 
            install_status=$?
        fi
        
        if [ $install_status -ne 0 ]; then
            # If 'fd' failed, try 'fd-find'
            echo "Package 'fd' not found. Attempting to install 'fd-find' instead..."
            
            if $QUIET_MODE; then
                $INSTALL_CMD "fd-find" > /dev/null 2>&1
                install_status=$?
            else
                $INSTALL_CMD "fd-find" 2>/dev/null 
                install_status=$?
            fi
            
            if [ $install_status -ne 0 ]; then
                echo "Warning: Failed to install 'fd' or 'fd-find'. This utility will be skipped."
            else
                echo "fd-find installed successfully."
                
                # Symlink Creation Logic for Debian/Ubuntu (apt systems)
                if [[ "$PKG_MANAGER" == "apt" ]]; then
                    mkdir -p "$HOME/.local/bin"
                    local FDFIND_PATH=$(which fdfind)
                    if [ -x "$FDFIND_PATH" ]; then
                        ln -s "$FDFIND_PATH" "$HOME/.local/bin/fd"
                        echo "Created symlink: $HOME/.local/bin/fd -> fdfind"
                    else
                        echo "Warning: fdfind binary not found after installation. Skipping symlink creation."
                    fi
                fi
            fi
        else
            echo "fd installed successfully."
        fi
    fi
    
    # --- Handle bat / batcat specially ---
    if command -v "bat" > /dev/null 2>&1; then
        echo "bat is already installed. Skipping."
    elif command -v "batcat" > /dev/null 2>&1; then
        echo "Found 'batcat'. Creating symlink to 'bat' in ~/.local/bin."
        mkdir -p "$HOME/.local/bin"
        ln -s "$(which batcat)" "$HOME/.local/bin/bat"
        echo "bat linked successfully."
    else
        echo "Attempting to install 'bat'..."
        local install_status=0
        
        if $QUIET_MODE; then
            $INSTALL_CMD "bat" > /dev/null 2>&1
            install_status=$?
        else
            $INSTALL_CMD "bat" 2>/dev/null 
            install_status=$?
        fi

        if [ $install_status -eq 0 ]; then
            # Check if installation resulted in 'bat' or 'batcat'
            if command -v "bat" > /dev/null 2>&1; then
                echo "bat installed successfully."
            elif command -v "batcat" > /dev/null 2>&1; then
                echo "Package 'bat' installed 'batcat'. Creating symlink to 'bat' in ~/.local/bin."
                mkdir -p "$HOME/.local/bin"
                ln -s "$(which batcat)" "$HOME/.local/bin/bat"
                echo "bat linked successfully."
            else
                echo "Warning: Installation of 'bat' succeeded but binary 'bat'/'batcat' not found. Skipping."
            fi
        else
            echo "Warning: Failed to install 'bat' (Exit code: $install_status). This utility will be skipped."
        fi
    fi
    echo "Finished installing general optional packages."
    
    # 3.3. Install zoxide via official script (curl | sh)
    echo -e "\n--- Installing zoxide via specialized script ---"
    
    if command -v "zoxide" > /dev/null 2>&1; then
        echo "zoxide is already installed. Skipping."
    else
        echo "Attempting to install zoxide..."
        # Use the official installation method for zoxide
        if $QUIET_MODE; then
            if curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh > /dev/null 2>&1; then
                echo "zoxide installed successfully."
            else
                echo "Warning: Failed to install optional package 'zoxide'. This package will be skipped."
            fi
        else
            if curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh; then
                echo "zoxide installed successfully."
            else
                echo "Warning: Failed to install optional package 'zoxide'. This package will be skipped."
            fi
        fi
    fi
}

# .zshrc Backup and Cleanup ---

create_zshrc_backup() {
    local ZSHRC_PATH="$HOME/.zshrc"
    local BACKUP_PATH="$HOME/.zshrc.bak"
    local OMZ_TEMPLATE="$HOME/.oh-my-zsh/templates/zshrc.zsh-template"
    
    echo -e "\n--- Creating Backup of Existing ~/.zshrc ---"
    
    if [ -f "$ZSHRC_PATH" ]; then
        
        cp "$ZSHRC_PATH" "$BACKUP_PATH"
        
        if [ $? -eq 0 ]; then
            echo "Backup created successfully: $BACKUP_PATH"
            echo "Removing original ~/.zshrc to ensure a clean base."
            
            # 1. Always remove the existing .zshrc for a fresh installation
            rm -f "$ZSHRC_PATH"

            # 2. If OMZ is installed, copy its template back so configure_zshrc has a base file.
            if [ -d "$HOME/.oh-my-zsh" ]; then
                if [ -f "$OMZ_TEMPLATE" ]; then
                    cp "$OMZ_TEMPLATE" "$ZSHRC_PATH"
                    echo "Replaced ~/.zshrc with a fresh Oh My Zsh template."
                else
                    echo "Warning: Oh My Zsh is installed, but the template file was not found. Proceeding with original ~/.zshrc."
                    echo "Original ~/.zshrc restored from backup."
                    cp "$BACKUP_PATH" "$ZSHRC_PATH"
                fi
            fi
        else
            echo "Warning: Failed to create backup of $ZSHRC_PATH. Original file retained."
        fi
    fi
}
# --- 4. ZSH CONFIGURATION AND OH MY ZSH INSTALLATION ---

install_oh_my_zsh() {
    echo -e "\n--- Installing Oh My Zsh ---"
    
    if [ -d "$HOME/.oh-my-zsh" ]; then
        echo "Oh My Zsh is already installed. Skipping installation."
    else
        # Use the curl method for unattended installation (output is largely suppressed by --unattended)
        # This will create a fresh ~/.zshrc because we removed the old one in create_zshrc_backup
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        if [ $? -ne 0 ]; then
            echo "Error: Failed to install Oh My Zsh."
            exit 1
        fi
        if ! $QUIET_MODE; then
            echo "Oh My Zsh installed successfully."
        fi
    fi
}

install_plugins() {
    echo -e "\n--- Installing Zsh Plugins (Autosuggestions, F-Sy-H, and Custom Autoupdate) ---"
    
    ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}
    
    # 1. zsh-autosuggestions
    AUTOSUGGEST_DIR="$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    if [ ! -d "$AUTOSUGGEST_DIR" ]; then
        echo "Installing zsh-autosuggestions..."
        if $QUIET_MODE; then
            git clone https://github.com/zsh-users/zsh-autosuggestions "$AUTOSUGGEST_DIR" > /dev/null 2>&1
        else
            git clone https://github.com/zsh-users/zsh-autosuggestions "$AUTOSUGGEST_DIR"
        fi
    else
        echo "zsh-autosuggestions already installed."
    fi

    # 2. F-Sy-H (Feature Rich Syntax Highlighting)
    HIGHLIGHT_DIR="$ZSH_CUSTOM/plugins/F-Sy-H"
    if [ ! -d "$HIGHLIGHT_DIR" ]; then
        echo "Installing F-Sy-H..."
        if $QUIET_MODE; then
            git clone https://github.com/z-shell/F-Sy-H.git "$HIGHLIGHT_DIR" > /dev/null 2>&1
        else
            git clone https://github.com/z-shell/F-Sy-H.git "$HIGHLIGHT_DIR"
        fi
    else
        echo "F-Sy-H already installed."
    fi

    # 3. Custom Autoupdate Plugin
    # Cloned to 'autoupdate' directory, which is used in plugins list.
    AUTOUPDATE_DIR="$ZSH_CUSTOM/plugins/autoupdate"
    if [ ! -d "$AUTOUPDATE_DIR" ]; then
        echo "Installing custom autoupdate-oh-my-zsh-plugins..."
        if $QUIET_MODE; then
            git clone https://github.com/tamcore/autoupdate-oh-my-zsh-plugins.git "$AUTOUPDATE_DIR" > /dev/null 2>&1
        else
            git clone https://github.com/tamcore/autoupdate-oh-my-zsh-plugins.git "$AUTOUPDATE_DIR"
        fi
    else
        echo "Custom autoupdate plugin already installed."
    fi
}

install_powerlevel10k() {
    if ! $QUIET_MODE; then
        echo -e "\n--- Installing Powerlevel10k Theme ---"
    fi
    
    local P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    
    if [ -d "$P10K_DIR" ]; then
        if ! $QUIET_MODE; then
            echo "Powerlevel10k is already installed. Skipping."
        fi
    else
        if ! $QUIET_MODE; then
            echo "Cloning Powerlevel10k repository..."
        fi
        
        local clone_status=0
        if $QUIET_MODE; then
            git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR" > /dev/null 2>&1
            clone_status=$?
        else
            git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
            clone_status=$?
        fi

        if [ $clone_status -ne 0 ]; then
            echo "Error: Failed to clone Powerlevel10k. Skipping theme installation."
        else
            if ! $QUIET_MODE; then
                echo "Powerlevel10k installed successfully."
            fi
        fi
    fi
}

setup_zsh_modular_config() {
    echo -e "\n--- Setting up ~/.zsh/ directory for modular configs ---"
    mkdir -p "$HOME/.zsh"
    
    # Create aliases.zsh file
    echo "Creating ~/.zsh/aliases.zsh..."
    cat > "$HOME/.zsh/aliases.zsh" << 'EOF'
alias zshconfig='vim ~/.zshrc'
alias zshreload='source ~/.zshrc'

# Alias's for multiple directory listing commands
alias la='ls -Alh'                  # show hidden files
alias ls='ls -aFh --color=always'   # add colors and file type extensions
alias lx='ls -lXBh'                 # sort by extension
alias lk='ls -lSrh'                 # sort by size
alias lc='ls -ltcrh'                # sort by change time
alias lu='ls -lturh'                # sort by access time
alias lr='ls -lRh'                  # recursive ls
alias lt='ls -ltrh'                 # sort by date
alias lm='ls -alh |more'            # pipe through 'more'
alias lw='ls -xAh'                  # wide listing format
alias ll='ls -Fls'                  # long listing format
alias labc='ls -lap'                # alphabetical sort
alias lf="ls -F | grep -v /"        # files only
alias ldir="ls -d */"               # directories only
alias lla='ls -Al'                  # List and Hidden Files
alias las='ls -A'                   # Hidden Files
alias lls='ls -l'                   # List

alias da='date "+%Y-%m-%d %A %T %Z"'

# Alias's to modified commands
alias cd='z'
alias cp='cp -i'
alias mv='mv -i'
alias mkdir='mkdir -p'
alias vim='nvim'
alias vi='nvim'

# Search running processes
alias topcpu="/bin/ps -eo pcpu,pid,user,args | sort -k 1 -r | head -10"

# Show open ports
alias openports='netstat -nape --inet'

# Alias's to show disk space and space used in a folder
alias diskspace="du -S | sort -n -r |more"
alias dufolders='du -h --max-depth=1'
alias tree='tree -CAhF --dirsfirst'
alias treed='tree -CAFd'
alias mountedinfo='df -hT'

# Change directory aliases
alias home='cd ~'
alias cd..='cd ..'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# IP address lookup
alias whatismyip="whatsmyip"
function whatsmyip () {
    # Internal IP Lookup.
    if command -v ip &> /dev/null; then
        echo -n "Internal IP: "
        # Assuming the common Linux interface name (eth0/enpXsX) or relying on 'ip addr' output pattern
        ip addr | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n 1
    else
        echo -n "Internal IP: "
        # Fallback for ifconfig (which might not be installed)
        ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n 1
    fi

    # External IP Lookup
    echo -n "External IP: "
    curl -s ifconfig.me
}
EOF
}

install_custom_scripts() {
    if ! $QUIET_MODE; then
        echo -e "\n--- Installing Custom Scripts ---"
    fi
    local SCRIPT_DIR_LOCAL="$(dirname "$(readlink -f "$0")")"
    local SCRIPT_SOURCE="$SCRIPT_DIR_LOCAL/custom_scripts"
    local SCRIPT_DESTINATION="$HOME/.local/bin"

    if [ ! -d "$SCRIPT_SOURCE" ]; then
        echo "Warning: Custom script source directory '$SCRIPT_SOURCE' not found. Skipping custom script installation."
        return
    fi
    
    mkdir -p "$SCRIPT_DESTINATION"
    
    if ! $QUIET_MODE; then
        echo "Copying scripts from $SCRIPT_SOURCE to $SCRIPT_DESTINATION and setting permissions..."
        cp "$SCRIPT_SOURCE"/* "$SCRIPT_DESTINATION"/
        chmod +x "$SCRIPT_DESTINATION"/*
        echo "Custom scripts installed successfully."
    else
        cp "$SCRIPT_SOURCE"/* "$SCRIPT_DESTINATION"/ > /dev/null 2>&1
        chmod +x "$SCRIPT_DESTINATION"/* > /dev/null 2>&1
        echo "Custom scripts installed silently."
    fi
}

install_fonts() {
    if ! $QUIET_MODE; then
        echo -e "\n--- Installing Custom Fonts ---"
    fi
    # Find the directory where this script is located
    local SCRIPT_DIR_LOCAL="$(dirname "$(readlink -f "$0")")"
    local FONT_SOURCE="$SCRIPT_DIR_LOCAL/fonts"
    local FONT_DESTINATION="$HOME/.local/share/fonts"

    if [ ! -d "$FONT_SOURCE" ]; then
        echo "Warning: Font source directory '$FONT_SOURCE' not found. Skipping font installation."
        return
    fi
    
    mkdir -p "$FONT_DESTINATION"
    if ! $QUIET_MODE; then
        echo "Copying fonts from $FONT_SOURCE to $FONT_DESTINATION..."
    fi
    
    # Copy all font file types, suppressing output
    find "$FONT_SOURCE" -type f \( -iname "*.ttf" -o -iname "*.otf" -o -iname "*.woff" -o -iname "*.woff2" \) -exec cp {} "$FONT_DESTINATION" \; > /dev/null 2>&1
    
    # Check the result of the copy command
    if [ $? -eq 0 ]; then
        if ! $QUIET_MODE; then
            echo "Fonts copied successfully. Updating font cache..."
        fi
        
        # Check if fc-cache exists before running and suppress output
        if command -v fc-cache > /dev/null 2>&1; then
            fc-cache -fv > /dev/null 2>&1
            if ! $QUIET_MODE; then
                echo "Font cache updated. You may need to restart your terminal emulator to see new fonts."
            fi
        else
            echo "Warning: fc-cache command not found. Font cache may not be immediately available."
        fi
    else
        echo "Error: Failed to copy fonts."
    fi
}


configure_zshrc() {
    echo -e "\n--- Configuring ~/.zshrc ---"
    
    # Define the plugins to enable, using 'autoupdate' (the directory name)
    local plugins_to_add="autoupdate git zsh-autosuggestions F-Sy-H"

    # 1. Set the Powerlevel10k theme using sed
    # This specifically looks for 'ZSH_THEME="..."' and replaces it.
    sed -i 's/^ZSH_THEME=".*"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$HOME/.zshrc"
    echo "Set ZSH_THEME to powerlevel10k/powerlevel10k."
    
    # 2. Update the plugins line using sed
    # This specifically looks for 'plugins=(...)' and replaces it.
    sed -i -E "s/plugins=\((.*)\)/plugins=($plugins_to_add)/g" "$HOME/.zshrc"

    # 3. Append custom configurations to ~/.zshrc

    echo -e "\n# --- Custom Configuration Added by Setup Script ---\n" >> "$HOME/.zshrc"
    
    # Add ~/.local/bin to PATH
    echo 'export PATH="$PATH:$HOME/.local/bin"' >> "$HOME/.zshrc"

    # Set Oh My Zsh update frequency to 30 days
    echo "export UPDATE_ZSH_DAYS=30" >> "$HOME/.zshrc"

    # Initialize zoxide (fast directory switcher)
    echo 'eval "$(zoxide init zsh)"' >> "$HOME/.zshrc"
    
    # --- History Expansion and Cleanup ---
    echo -e "\n# --- History Expansion and Cleanup ---\n" >> "$HOME/.zshrc"
    echo "# Expand the history size" >> "$HOME/.zshrc"
    echo 'export HISTFILE="$HOME/.zsh_history"' >> "$HOME/.zshrc"
    echo "export HISTSIZE=1000000" >> "$HOME/.zshrc"
    echo 'export HISTTIMEFORMAT="%F %T"' >> "$HOME/.zshrc"
    echo "export SAVEHIST=\$HISTSIZE" >> "$HOME/.zshrc"
    echo "setopt EXTENDED_HISTORY" >> "$HOME/.zshrc"
    echo "setopt SHARE_HISTORY" >> "$HOME/.zshrc"
    echo "setopt HIST_EXPIRE_DUPS_FIRST" >> "$HOME/.zshrc"
    echo "setopt HIST_IGNORE_DUPS" >> "$HOME/.zshrc"
    echo "setopt HIST_IGNORE_ALL_DUPS" >> "$HOME/.zshrc"
    echo "setopt HIST_FIND_NO_DUPS" >> "$HOME/.zshrc"
    echo "setopt HIST_IGNORE_SPACE" >> "$HOME/.zshrc"
    echo "setopt HIST_SAVE_NO_DUPS" >> "$HOME/.zshrc"
    echo "setopt HIST_REDUCE_BLANKS" >> "$HOME/.zshrc"
    
    # --- Source Modular Config Files ---
    echo -e "\n# --- Source Modular Config Files (~/.zsh/*.zsh) ---\n" >> "$HOME/.zshrc"
    echo "for config in ~/.zsh/*.zsh; do source \$config; done" >> "$HOME/.zshrc"
    
    # --- FZF and FD Integration ---
    echo -e "\n# --- FZF (Fuzzy Finder) and FD Integration ---\n" >> "$HOME/.zshrc"

    # Set up fzf key bindings and fuzzy completion
    echo "source <(fzf --zsh)" >> "$HOME/.zshrc"

    # Check if eza and bat are available for advanced FZF previews
    if command -v eza &> /dev/null && command -v bat &> /dev/null; then
        echo "FZF: Adding advanced previews using eza and bat."
        local show_file_or_dir_preview="if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"
        
        # Customize fzf commands to use fd for faster, hidden-aware searching
        echo 'export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"' >> "$HOME/.zshrc"
        echo 'export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"' >> "$HOME/.zshrc"
        
        # FZF options for previewing files and directories
        echo "export FZF_CTRL_T_OPTS=\"--preview '$show_file_or_dir_preview'\"" >> "$HOME/.zshrc"
        echo "export FZF_ALT_C_OPTS=\"--preview 'eza --tree --color=always {} | head -200'\"" >> "$HOME/.zshrc"

        # Advanced customization of fzf options via _fzf_comprun function
        echo "# Advanced customization of fzf options via _fzf_comprun function" >> "$HOME/.zshrc"
        echo "_fzf_comprun() {" >> "$HOME/.zshrc"
        echo "  local command=\$1" >> "$HOME/.zshrc"
        echo "  shift" >> "$HOME/.zshrc"
        echo "" >> "$HOME/.zshrc"
        echo "  case \"\$command\" in" >> "$HOME/.zshrc"
        echo "    cd)            fzf --preview 'eza --tree --color=always {} | head -200' \"\$@\" ;;" >> "$HOME/.zshrc"
        echo "    export|unset) fzf --preview \"eval 'echo \${}'\"         \"\$@\" ;;" >> "$HOME/.zshrc"
        echo "    ssh)           fzf --preview 'dig {}'                   \"\$@\" ;;" >> "$HOME/.zshrc"
        echo "    *)             fzf --preview \"\$show_file_or_dir_preview\" \"\$@\" ;;" >> "$HOME/.zshrc"
        echo "  esac" >> "$HOME/.zshrc"
        echo "}" >> "$HOME/.zshrc"
        
        echo "# Use fd (https://github.com/sharkdp/fd) for listing path candidates." >> "$HOME/.zshrc"
        echo "# - The first argument to the function (\$1) is the base path to start traversal" >> "$HOME/.zshrc"
        echo "_fzf_compgen_path() {" >> "$HOME/.zshrc"
        echo '  fd --hidden --exclude .git . "$1"' >> "$HOME/.zshrc"
        echo "}" >> "$HOME/.zshrc"

        echo "# Use fd to generate the list for directory completion" >> "$HOME/.zshrc"
        echo "_fzf_compgen_dir() {" >> "$HOME/.zshrc"
        echo '  fd --type=d --hidden --exclude .git . "$1"' >> "$HOME/.zshrc"
        echo "}" >> "$HOME/.zshrc"
    
    else
        echo "FZF: eza or bat not found. Skipping advanced preview configuration."
        
        # Keep basic FZF configuration if eza/bat are missing
        echo 'export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"' >> "$HOME/.zshrc"
        echo 'export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"' >> "$HOME/.zshrc"
        echo 'export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"' >> "$HOME/.zshrc"
        
        echo "# Use fd (https://github.com/sharkdp/fd) for listing path candidates." >> "$HOME/.zshrc"
        echo "# - The first argument to the function (\$1) is the base path to start traversal" >> "$HOME/.zshrc"
        echo "_fzf_compgen_path() {" >> "$HOME/.zshrc"
        echo '  fd --hidden --exclude .git . "$1"' >> "$HOME/.zshrc"
        echo "}" >> "$HOME/.zshrc"

        echo "# Use fd to generate the list for directory completion" >> "$HOME/.zshrc"
        echo "_fzf_compgen_dir() {" >> "$HOME/.zshrc"
        echo '  fd --type=d --hidden --exclude .git . "$1"' >> "$HOME/.zshrc"
        echo "}" >> "$HOME/.zshrc"
    fi
    
    # --- ripgrep alias ---
    echo -e "\n# --- ripgrep Configuration ---\n" >> "$HOME/.zshrc"
    
    # Check if ripgrep is installed
    echo "if command -v rg &> /dev/null; then" >> "$HOME/.zshrc"
    # Alias grep to rg if ripgrep is installed
    echo "    alias grep='rg'" >> "$HOME/.zshrc"
    echo "else" >> "$HOME/.zshrc"
    # Alias grep to /usr/bin/grep with GREP_OPTIONS if ripgrep is not installed
    echo '    alias grep="/usr/bin/grep $GREP_OPTIONS"' >> "$HOME/.zshrc"
    echo "fi" >> "$HOME/.zshrc"
    echo "unset GREP_OPTIONS" >> "$HOME/.zshrc"

    # --- History Management Function ---
    echo -e "\n# --- Custom History Management (zshaddhistory) ---\n" >> "$HOME/.zshrc"
    echo "zshaddhistory() {" >> "$HOME/.zshrc"
    echo '    local line=${1%%$'\n'}' >> "$HOME/.zshrc"
    echo '    local cmd=${line%% *}' >> "$HOME/.zshrc"
    echo "    # Only those that satisfy all of the following conditions are added to the history" >> "$HOME/.zshrc"
    echo "    [[ \${#line} -ge 5" >> "$HOME/.zshrc"
    echo '        && ${cmd} != ll' >> "$HOME/.zshrc"
    echo '        && ${cmd} != ls' >> "$HOME/.zshrc"
    echo '        && ${cmd} != la' >> "$HOME/.zshrc"
    echo '        && ${cmd} != cd' >> "$HOME/.zshrc"
    echo '        && ${cmd} != man' >> "$HOME/.zshrc"
    echo '        && ${cmd} != less' >> "$HOME/.zshrc"
    echo '        && ${cmd} != file' >> "$HOME/.zshrc"
    echo '        && ${cmd} != which' >> "$HOME/.zshrc"
    echo '        && ${cmd} != drill' >> "$HOME/.zshrc"
    echo '        && ${cmd} != md5sum' >> "$HOME/.zshrc"
    echo '        && ${cmd} != pacman' >> "$HOME/.zshrc"
    echo '        && ${cmd} != xdg-open' >> "$HOME/.zshrc"
    echo '        && ${cmd} != traceroute' >> "$HOME/.zshrc"
    echo '        && ${cmd} != speedtest-cli' >> "$HOME/.zshrc"
    echo '        && ${cmd} != j' >> "$HOME/.zshrc"
    echo '        && ${cmd} != ji' >> "$HOME/.zshrc"
    echo '        && ${cmd} != z' >> "$HOME/.zshrc"
    echo '        && ${cmd} != zi' >> "$HOME/.zshrc"
    echo '        && ${cmd} != rm' >> "$HOME/.zshrc"
    echo "    ]]" >> "$HOME/.zshrc"
    echo "}" >> "$HOME/.zshrc"
    echo "zshaddhistory" >> "$HOME/.zshrc"


    echo "Updated ~/.zshrc to enable plugins: ($plugins_to_add)"
    echo "Set auto-update frequency to 30 days and initialized zoxide."
    echo "Added custom fzf/fd configuration and optimized history."
}

set_default_shell() {
    echo -e "\n--- Setting Zsh as Default Shell ---"
    
    # Use chsh to change the default shell. This is usually interactive and asks for a password.
    if [ "$SHELL" != "$(which zsh)" ]; then
        echo "The 'chsh' command will now ask for your password to change your default shell to Zsh."
        chsh -s "$(which zsh)"
        echo "Default shell successfully set to Zsh."
    else
        echo "Zsh is already set as the default shell."
    fi
}

# --- 5. EXECUTION FLOW ---

main() {
    # Check for arguments
    for arg in "$@"; do
        if [ "$arg" == "--quiet" ]; then
            QUIET_MODE=true
            echo "Running setup in quiet mode. Installation details suppressed."
        fi
    done
    
    # 1. Detect OS and set package manager variables
    detect_os
    
    # 2. Install Zsh, Git, Curl, and the new utilities
    install_prerequisites
    
    # 2.5. Create ZshRC Backup AND REMOVE ORIGINAL for clean OMZ install
    create_zshrc_backup
    
    # 3. Install Oh My Zsh (This will either install it or skip, but the ~/.zshrc is already a clean template)
    install_oh_my_zsh
    
    # 4. Install Plugins
    install_plugins
    
    # 4.5. Install Powerlevel10k theme
    install_powerlevel10k
    
    # 4.6. Create modular config directory and aliases file
    setup_zsh_modular_config
    
    # 4.7. Install Custom Scripts
    install_custom_scripts
    
    # 5. Configure ZshRC
    configure_zshrc
    
    # 5.5. Install Fonts
    install_fonts
    
    # 6. Set Default Shell
    set_default_shell
    
    # User requested message about the backup file
    echo -e "\nℹ️ IMPORTANT: Your original/previous ~/.zshrc file was backed up to ~/.zshrc.bak before configuration began."

    echo -e "\n✅ Setup Complete! ✅"
    echo "Please log out and log back in, or run 'exec zsh' to start using your new Zsh shell with plugins."
}

# Execute the main function
main "$@"