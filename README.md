# Zsh and Oh My Zsh Automated Setup Script

This script installs Zsh, the Oh My Zsh framework, and key plugins on Debian/Ubuntu, CentOS, and Rocky Linux systems.

## Installation
```sh
git clone --depth 1 https://github.com/tomta555/zsh-setup-script.git ~/.zsh-setup
~/.zsh-setup/setup.sh --quiet
```

After the installation is completed, restart the shell process/session to setup p10k configure.

- **Important**: This script is intended for use on a flesh system installation or on a system that does not have zsh. 
- If this script is executed on a system with zsh, the `.zshrc` file will be backed up at `~/.zshrc.bak`

## What the script does

- Update package lists
- Install zsh, git, curl, and neovim
- Install bat, eza, fastfetch, fd, fzf, and zoxide
- Create .zshrc backup and remove original .zshrc
- Install Oh My Zsh
- Install autoupdate, syntax highlight, and auto-suggestion OMZ plugin
- Install powerlevel10k theme
- Configure the .zshrc file and add command aliases
- Install MesloLGS NF font
- Set default shell to zsh

## Supported Operating Systems

- Ubuntu/Debian
- CentOS
- Rocky Linux

## For References
- [bat](https://github.com/sharkdp/bat)
- [eza](https://github.com/eza-community/eza)
- [fastfetch](https://github.com/fastfetch-cli/fastfetch)
- [fd](https://github.com/sharkdp/fd)
- [fzf](https://github.com/junegunn/fzf)
- [zoxide](https://github.com/ajeetdsouza/zoxide)
- [autoupdate](https://github.com/tamcore/autoupdate-oh-my-zsh-plugins)
- [F-Sy-H](https://github.com/z-shell/F-Sy-H)
- [Powerlevel10k](https://github.com/romkatv/powerlevel10k)
- [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
