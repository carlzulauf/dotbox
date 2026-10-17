# Voice dictation with Voxtype (https://voxtype.io): speech-to-text that runs
# locally and types the result into whatever has focus, so it works the same
# for Claude Code, pi, and browser text fields.
#
#   Super+Q        start dictating; press again to stop and type the text
#   Super+Shift+Q  the same, transcribed with the alternate model (if set)
#
# The shortcut that starts a recording picks its model. Pressing either one
# again stops it.
#
# Old recordings: `voxtype transcribe file.wav` (any engine's model with
# `voxtype --model <name> transcribe file.wav`).
#
# Voxtype's own hotkey reads /dev/input directly and doesn't grab the key, so
# the key would also reach the focused app. GNOME custom shortcuts drive it
# instead (toggle only: GNOME shortcuts never see a key release, so there is
# no hold-to-talk). Text is typed through dotool (/dev/uinput), since GNOME
# doesn't implement the virtual keyboard protocol wtype needs.
#
# Filler words ("uh", "um", ...) are dropped by voxtype's built-in filter
# ([text] filter_filler_words, on by default). No LLM cleanup pass yet.
{ config, lib, pkgs, voxtype, ... }:
let
  cfg = config.dotbox.dictation;
  user = "carl";
  system = pkgs.stdenv.hostPlatform.system;

  # Every voxtype invocation reads this file, through the wrapper below. On its
  # own, voxtype prefers ~/.config/voxtype/config.toml and only falls back to
  # /etc, and `voxtype setup` creates the user file when it's missing, which
  # would silently replace everything configured here.
  configPath = "/etc/voxtype/config.toml";

  # CPU build with every ONNX engine (Cohere, Parakeet, ...) plus Whisper.
  onnxUnwrapped = voxtype.packages.${system}.voxtype-onnx-unwrapped;

  # Upstream ships Whisper-on-Vulkan and the ONNX engines as separate builds;
  # the cargo features combine fine, so one binary gets both. Only Whisper
  # uses the GPU, the ONNX engines stay on the CPU.
  vulkanFeatures = onnxUnwrapped.cargoBuildFeatures ++ [ "gpu-vulkan" ];
  vulkanUnwrapped = onnxUnwrapped.overrideAttrs (old: {
    pname = "voxtype-onnx-vulkan";
    cargoBuildFeatures = vulkanFeatures;
    cargoCheckFeatures = vulkanFeatures;
    nativeBuildInputs = old.nativeBuildInputs ++ (with pkgs; [
      shaderc vulkan-headers vulkan-loader
    ]);
    buildInputs = old.buildInputs ++ (with pkgs; [ vulkan-headers vulkan-loader ]);
    preBuild = old.preBuild + ''
      export VULKAN_SDK="${pkgs.vulkan-loader}"
      export Vulkan_INCLUDE_DIR="${pkgs.vulkan-headers}/include"
      export Vulkan_LIBRARY="${pkgs.vulkan-loader}/lib/libvulkan.so"
    '';
  });

  unwrapped = if cfg.vulkan then vulkanUnwrapped else onnxUnwrapped;

  # Same runtime environment as upstream's wrapped ONNX packages, plus the
  # pinned config path. onnxruntime is the one the build linked against
  # (voxtype's nixpkgs follows ours). The user services' PATH has little more
  # than coreutils, so it also gets curl (model downloads) and which (output
  # drivers are only used when `which <driver>` finds them).
  package = pkgs.symlinkJoin {
    name = "voxtype-${unwrapped.version}";
    paths = [ unwrapped ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/voxtype \
        --add-flags "--config ${configPath}" \
        --prefix PATH : ${lib.makeBinPath (with pkgs; [
          dotool wtype wl-clipboard libnotify pciutils curl which
        ])} \
        --set ORT_DYLIB_PATH "${pkgs.onnxruntime}/lib/libonnxruntime.so" \
        --prefix LD_LIBRARY_PATH : "${pkgs.onnxruntime}/lib"
    '';
    inherit (unwrapped) meta;
  };
  voxtypeBin = "${package}/bin/voxtype";

  settings = lib.recursiveUpdate {
    state_file = "auto";
    inherit (cfg) engine;
    # driven by the GNOME shortcuts below
    hotkey.enabled = false;
    audio = {
      # upstream's 60s cap is short for talking through a prompt
      max_duration_secs = 300;
      # beeps on start/stop stand in for the OSD (below)
      feedback.enabled = true;
    };
    # the OSD is a layer-shell overlay, which GNOME doesn't support
    osd.enabled = false;
    # Drop recordings with no speech in them. Without this a silent recording
    # turns into invented text (Cohere made "Şivčićićićí" of 13s of room
    # noise) typed into whatever has focus. Silero rather than the energy
    # detector the ONNX engines get by default.
    vad = {
      enabled = true;
      backend = "whisper";
    };
    output = {
      mode = "type";
      driver_order = [ "dotool" "clipboard" ];
      fallback_to_clipboard = true;
    };
  } (lib.mapAttrs (_engine: model: { inherit model; }) cfg.models);

  # GNOME keeps its custom shortcut list in one dconf key that apps rewrite
  # (Zoom adds and removes its own entries), so a system dconf default would be
  # shadowed by the user's copy. Merge ours into the user's list at login,
  # leaving every other entry alone.
  mediaKeys = "/org/gnome/settings-daemon/plugins/media-keys";
  shortcuts = [
    {
      id = "voxtype";
      name = "Dictation (${cfg.models.${cfg.engine}})";
      binding = cfg.shortcut;
      command = "${voxtypeBin} record toggle";
    }
  ] ++ lib.optional (cfg.alternateEngine != null) {
    id = "voxtype-alternate";
    name = "Dictation (${cfg.models.${cfg.alternateEngine}})";
    binding = cfg.alternateShortcut;
    command = "${voxtypeBin} record toggle --model ${cfg.models.${cfg.alternateEngine}}";
  };
  shortcutPath = id: "${mediaKeys}/custom-keybindings/${id}/";
  installShortcuts = pkgs.writeShellScript "voxtype-shortcuts" ''
    set -eu
    dconf=${pkgs.dconf}/bin/dconf
    key=${mediaKeys}/custom-keybindings

    # everyone else's entries, minus any voxtype ones (re-added below)
    entries=$($dconf read $key | grep -o "'[^']*'" | grep -v "/custom-keybindings/voxtype" || true)
    $dconf reset -f ${shortcutPath "voxtype-alternate"}

    ${lib.concatMapStrings (s: ''
      entries="$entries
      '${shortcutPath s.id}'"
      $dconf write ${shortcutPath s.id}name "'${s.name}'"
      $dconf write ${shortcutPath s.id}binding "'${s.binding}'"
      $dconf write ${shortcutPath s.id}command "'${s.command}'"
    '') shortcuts}

    list=$(echo "$entries" | sed 's/^ *//' | grep . | paste -sd, - | sed 's/,/, /g')
    $dconf write $key "[$list]"
  '';
in
{
  options.dotbox.dictation = with lib; {
    models = mkOption {
      type = types.attrsOf types.str;
      default = { parakeet = "parakeet-tdt-0.6b-v2"; };
      example = { cohere = "cohere-transcribe-q4f16"; whisper = "large-v3-turbo"; };
      description = ''
        Model for each engine to keep available, as engine = model. Each is
        downloaded at login and written to its engine's config section.
      '';
    };
    engine = mkOption {
      type = types.str;
      default = "parakeet";
      description = "Engine the main shortcut uses; must be one of models.";
    };
    alternateEngine = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Engine for the alternate shortcut; must be one of models.";
    };
    vulkan = mkEnableOption "Whisper on the GPU through Vulkan (ONNX engines stay on the CPU)";
    shortcut = mkOption {
      type = types.str;
      default = "<Super>q";
    };
    alternateShortcut = mkOption {
      type = types.str;
      default = "<Super><Shift>q";
    };
  };

  config = {
    assertions = [
      {
        assertion = cfg.models ? ${cfg.engine};
        message = "dotbox.dictation.engine (${cfg.engine}) has no entry in dotbox.dictation.models";
      }
      {
        assertion = cfg.alternateEngine == null || cfg.models ? ${cfg.alternateEngine};
        message = "dotbox.dictation.alternateEngine has no entry in dotbox.dictation.models";
      }
    ];

    environment.systemPackages = [ package ];
    environment.etc."voxtype/config.toml".source =
      (pkgs.formats.toml { }).generate "voxtype-config.toml" settings;

    # dotool types through /dev/uinput
    hardware.uinput.enable = true;
    users.users.${user}.extraGroups = [ "uinput" ];

    # Models live in ~/.local/share/voxtype/models. Already-downloaded ones are
    # checked and skipped, so this is quick after the first login.
    systemd.user.services.voxtype-models = {
      description = "Download Voxtype speech models";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # first login may come before the network does
        Restart = "on-failure";
        RestartSec = 60;
      };
      script = lib.concatMapStringsSep "\n" (model:
        "${voxtypeBin} setup --download --model ${model} --quiet --no-post-install"
      ) (lib.attrValues cfg.models) + ''

        ${voxtypeBin} setup vad
      '';
    };

    systemd.user.services.voxtype = {
      description = "Voxtype dictation daemon";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      wants = [ "voxtype-models.service" ];
      after = [ "graphical-session.target" "voxtype-models.service" ];
      serviceConfig = {
        ExecStart = "${voxtypeBin} daemon";
        Restart = "on-failure";
        RestartSec = 10;
      };
    };

    systemd.user.services.voxtype-shortcuts = {
      description = "Add Voxtype dictation shortcuts to GNOME";
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = installShortcuts;
      };
    };
  };
}
