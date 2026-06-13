#!/usr/bin/env bash

# 📁 Validate that devenv is correctly linked
if [ ! -d "/etc/nixos/devenv" ]; then
  echo "/etc/nixos/devenv missing.  Suggestion: run the cmds below"
  echo "rm -rf /etc/nixos ; sudo ln -s ~/nixos-config /etc/nixos"
  exit 1
fi

# ✅ Check for SSH key
if [ ! -f "$HOME/.ssh/id_rsa" ]; then
  echo "❗ ssh key setup required. use nixos setup notes"
  echo "Press Enter after creating your SSH key to continue..."
  read -r
  if [ ! -f "$HOME/.ssh/id_rsa" ]; then
    echo "❌ id_rsa still missing; aborting."
    exit 1
  fi
fi


# Install flatpak for intellij Idea ultimate.  This install method avoids .so library
# sharing which nixos makes tricky due to non-standard paths.  But it duplicates .so libs that
# otherwise would be shared...  That's the price we have to pay to run idea though.
#
flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y --user flathub com.jetbrains.IntelliJ-IDEA-Ultimate
flatpak list --user | grep IntelliJ || echo "⚠️ WARNING IntelliJ not found for user chris"

#  supress annoying nautilus file mgr warnings
touch ~/.gtk-bookmarks
mkdir -p ~/.cache/thumbnails/normal

# ✅ Restore MATE panel, terminal, etc config from dconf backup
dconf load / < /etc/nixos/devenv/mate-dconf-backup.ini
dconf load /org/mate/panel/ < /etc/nixos/devenv/mate-panel-dconf-backup.ini

# ✅ Restore sound settings
sudo amixer set Master unmute
sudo amixer set Master 80%

echo "🔧 Checking Dropbox bootstrap..."

if [ ! -d "$HOME/.dropbox-dist" ]; then
  echo "📦 First-time Dropbox initialization... Takes about 5 minutes, then you will see OS prompt"
  cd /home/chris                    #   ensures Dropbox sets up its files under ~/.dropbox-dist and ~/Dropbox
  dropbox start -i
  echo "✅ Dropbox GUI should prompt for login. Once done, press Enter to continue..."
  read -r
else
  echo "✅ Dropbox already initialized."
  if ! pgrep -f ".dropbox-dist/.*/dropbox" >/dev/null 2>&1; then
    echo "🚀 Starting Dropbox daemon..."
    dropbox start
  else
    echo "⏭️  Dropbox daemon already running, skipping start."
  fi

fi

# Verify Dropbox actually started
for i in {1..12}; do   # wait up to 60s
    if pgrep -f ".dropbox-dist/.*/dropbox" >/dev/null 2>&1 && [ -S "$HOME/.dropbox/command_socket" ]; then
        echo "✅ Dropbox daemon is running and socket is ready."
        break
    else
        echo "… waiting for Dropbox daemon to come up ($i/12)"
        sleep 5
    fi
done

if ! pgrep -f ".dropbox-dist/.*/dropbox" >/dev/null 2>&1 || [ ! -S "$HOME/.dropbox/command_socket" ]; then
    echo "❌ Dropbox failed to start, aborting setup."
    exit 1
fi



echo "⚙️ Ensuring Dropbox autostarts on login..."

AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"

cat > "$AUTOSTART_DIR/dropbox.desktop" <<EOF
[Desktop Entry]
Type=Application
Exec=dropbox start
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Dropbox
Comment=Start Dropbox on login
EOF

chmod +x "$AUTOSTART_DIR/dropbox.desktop"

echo "✅ Dropbox autostart configured via desktop entry."



# ✅ Wait for Dropbox to finish syncing required files
REQUIRED_FILES=(
    $HOME/Dropbox/projects/devEnv/scripts
    $HOME/Dropbox/projects/devEnv/config/.ideavimrc 
    $HOME/Dropbox/projects/devEnv/config/vim 
    $HOME//Dropbox/projects/devEnv/config/ssh 
)

echo "⏳ Waiting for Dropbox to sync required files..."
for f in "${REQUIRED_FILES[@]}"; do
  until [ -f "$f" -o  -d "$f"  ]; do
    echo "… still waiting for $f"
    sleep 5
  done
  echo "✓ Found $f"
done

echo "🎯 Dropbox milestone reached — safe to continue."

bash /etc/nixos/devenv/claude/setup.sh





# 📦 First-time Insync setup
echo "🔧 Checking Insync bootstrap..."

if [ ! -d "$HOME/.config/Insync" ]; then
  echo "📦 First-time Insync initialization..."
  (cd $HOME ; insync start &)		# running from /etc/nixos causes issues
  echo "✅ Insync GUI should prompt for login. Once done, press Enter to continue..."
  read -r
else
  echo "✅ Insync already initialized."
fi

echo "⚙️ Ensuring Insync autostarts on login..."

cat > "$AUTOSTART_DIR/insync.desktop" <<EOF

[Desktop Entry]
Type=Application
Exec=insync start
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Insync
Comment=Start Insync on login
EOF

chmod +x "$AUTOSTART_DIR/insync.desktop"

echo "✅ Insync autostart configured via desktop entry."


# 📦 Trezor Suite setup
echo "🔧 Checking Trezor Suite..."

TREZOR_DIR="$HOME/.local/share/trezor-suite"
TREZOR_APP="$TREZOR_DIR/Trezor-Suite-25.8.2-linux-x86_64.AppImage"

mkdir -p "$TREZOR_DIR"
if [ ! -f "$TREZOR_APP" ]; then
  echo "📥 Downloading Trezor Suite AppImage..."
  wget -q https://data.trezor.io/suite/releases/desktop/latest/Trezor-Suite-25.8.2-linux-x86_64.AppImage -O "$TREZOR_APP"
  chmod +x "$TREZOR_APP"
else
  echo "✅ Trezor Suite AppImage already present."
fi

# Ensure alias is present
if ! grep -q "alias trez=" "$HOME/.bashrc"; then
  echo "alias trez='pushd /home/chris ; nix-shell -p appimage-run --run \"appimage-run $TREZOR_APP\" ; popd'" >> "$HOME/.bashrc"
  echo "✅ Added trez alias to ~/.bashrc"
else
  echo "⏭️  trez alias already configured in ~/.bashrc"
fi


cd $HOME


GIT_IGNORE=$HOME/Dropbox/projects/devEnv/config/.gitignore  
if  [ ! -e "$GIT_IGNORE" ]  ; then 
    ln -s  ~/Dropbox/projects/devEnv/config/.gitignore  ~/.gitignore
fi

CONFIG_SYMLINK=$HOME/Dropbox/projects/devEnv/config/
if  [ ! -e "$CONFIG_SYMLINK" ]  ; then 
    ln -s $CONFIG_SYMLINK
fi



## ssh config
rm -rf ~/.ssh
ln -s $HOME/Dropbox/projects/devEnv/config/ssh ~/.ssh
chmod 500  ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa*
chmod 700 ~/.ssh


rm -f $HOME/config
ln -s Dropbox/projects/devEnv/config/

rm -f $HOME/scripts
ln -s Dropbox/projects/devEnv/scripts

rm -f $HOME/.vimrc
ln -s /etc/nixos/devenv/vim.rc  .vimrc




rm -f $HOME/.ideavimrc
ln -s Dropbox/projects/devEnv/config/.ideavimrc .ideavimrc

rm -rf $HOME/.vim
ln -s Dropbox/projects/devEnv/config/vim .vim


grep "config.bashrc"  ~/.bashrc
if [ "$?"  -eq  "0" ] ; then
	echo skipping bashrc config
else
	echo adding bashrc config
	echo ". \$HOME/config/bashrc" >> ~/.bashrc
fi


## Password setup
/etc/nixos/devenv/change_passwd.sh

