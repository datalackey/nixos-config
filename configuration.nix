{ config, pkgs, lib,  ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  nixpkgs.config.allowUnfree = true;

  # ✅ Enable nix-command and flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  boot.kernel.sysctl."fs.inotify.max_user_watches" = 524288;

  time.timeZone = "America/Los_Angeles";

  systemd.tmpfiles.rules = [
    "d /tmp 1777 root root 20d"
  ];

  services.xserver = {
    enable = true;
    desktopManager.mate.enable = true;
    displayManager.lightdm.enable = true;
  };

  virtualisation.docker.enable = true;
  virtualisation.virtualbox.host.enable = true;
  virtualisation.virtualbox.host.enableExtensionPack = true;

  users.groups.chris = {};

  users.users.chris = {
    isNormalUser = true;
    group = "chris";
    extraGroups = [ "wheel" "networkmanager" "docker" "vboxusers" "lp" "scanner" ];
    initialHashedPassword = lib.removeSuffix "\n" (builtins.readFile ./secrets/chris-password);

  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };



services.printing = {
  enable = true;
  drivers = [ pkgs.hplip ];
  browsing = false;
  listenAddresses = [ "localhost:631" ];

  # Static printer definition written directly to cupsd.conf
  extraConf = ''
    <Printer HP6960>
      Info HP OfficeJet Pro 6960
      DeviceURI ipp://192.168.1.66/ipp/print
      Model everywhere
      State Idle
      Accepting Yes
      Shared No
    </Printer>
  '';
};

# And make sure cups-browsed stays off
systemd.services.cups-browsed.enable = false;



  hardware.sane.enable = true;
  hardware.sane.extraBackends = [ pkgs.hplip ];

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  services.resolved.enable = false;

  # ✅ NSS config for .local resolution
  system.nssModules = [ pkgs.nssmdns ];
  environment.extraOutputsToInstall = [ "out" "lib" ];


  #####################  AUDIO & SPEECH TO TEXT ################
  # ✅ PipeWire + PulseAudio compatibility
  sound.enable = true;

  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # ✅ ALSA softvol config to limit volume to safe levels
  environment.etc."asound.conf".text = ''
    pcm.!default {
        type plug
        slave.pcm "softvol"
    }

    pcm.softvol {
        type softvol
        slave {
            pcm "hw:0"
        }
        control {
            name "Master"
            card 0
        }
        max_dB -10.0
    }
  '';

  #####################  AUDIO & SPEECH TO TEXT (end) ################


  programs.bash.interactiveShellInit = ''
    eval "$(direnv hook bash)"
  '';

  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [
    gh          # github client tools

    nodejs                  # needed for GAS development  -- clasp .. gcloud etc
    google-cloud-sdk

    vlc


    yt-dlp      # generic video downloader

    graphviz    # plant uml support, etc

    cargo           # so we can do: cargo install --git https://github.com/asciinema/agg 
    asciinema

    direnv
    tree
    xclip

    alsa-utils

    temurin-bin-17

    zip
    unzip

    gnome.nautilus

    dejavu_fonts
    liberation_ttf
    freefont_ttf
    nerdfonts
    ubuntu_font_family

    libsForQt5.kolourpaint
    kdePackages.breeze-icons
    kdePackages.kconfig
    kdePackages.kiconthemes
    kdePackages.kio

    gnome.adwaita-icon-theme
    mate.mate-icon-theme

    python3
    python3Packages.venvShellHook

    firefox
    google-chrome

    curl
    wget

    git
    vim-full
    jq
    openssh
    xclip
    neofetch
    networkmanagerapplet

    dropbox
    mate.mate-indicator-applet

    docker-compose

    brasero
    wireshark
    lsscsi
    libappindicator-gtk3

    xsane
    simple-scan
    hplip

    mpv
    vim
    (vim_configurable.overrideAttrs (old: { gui = "gtk"; }))

    nssmdns

    # >>> nerd-dictation (speech2text) deps >>>
    gcc                # ensures libstdc++ is available
    stdenv.cc.cc.lib   # libgcc_s/libc runtime
    pulseaudio         # pactl / CLI tools
    sox                # mic testing & capture
    xdotool            # type into X
    # <<< end >>>
  ];




  environment.variables = {
    JAVA_HOME = "${pkgs.temurin-bin-17}";
    # Combine SANE's default with the C++ runtime libs; force wins the conflict.
    # This preserves scanners (/etc/sane-libs) and gives Vosk/nerd-dictation 
    # libstdc++ & friends, without nix-shell.
    #
    LD_LIBRARY_PATH = lib.mkForce "/etc/sane-libs:${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.gcc.cc.lib}/lib";
  };

  systemd.services."systemd-tmpfiles-clean".startAt = "daily";

  services.journald = {
    storage = "volatile";
    rateLimitInterval = "30s";
    rateLimitBurst = 1000;
  };

  ################################
  # User service: warm Vosk model once after login (low priority)
  ################################

  systemd.user.services.talk-warmup = {
    description = "Warm Vosk/nerd-dictation model cache once after login";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "oneshot";
      Nice = 19;
      IOSchedulingClass = "idle";
      ExecStart = "${pkgs.bash}/bin/bash -lc '/home/chris/scripts/DEVENV/talk begin --timeout=1 --full-sentence --numbers-as-digits'";
      WorkingDirectory = "/home/chris";

    };
  };


  system.stateVersion = "24.05";
}

