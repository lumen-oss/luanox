{ pkgs, config, lib, ... }:

let
  user = config.env.DATABASE_USER;
  pass = config.env.DATABASE_PASS;
in
{
    env.DATABASE_URL="postgres://${user}:${pass}@127.0.0.1/luanox";
    env.MIX_TAILWIND_PATH = "${pkgs.tailwindcss_4}/bin/tailwindcss";

    dotenv = {
        enable = true;
        filename = [ ".env.dev" ".env.prod" ];
    };

    languages.elixir = {
        enable = true;
        lsp.package = pkgs.beamPackages.expert;
    };

    languages.nix.enable = true;

    packages = with pkgs; [
      yarn          # Bundled JS dependencies
      alejandra     # Nix formatter
      tailwindcss_4 # We cannot use the bundled TailwindCSS CLI from Phoenix on NixOS
      inotify-tools # Required for file watching on Phoenix
      watchman      # Required for file watching on TailwindCSS CLI
    ];

    # https://devenv.sh/services/
    services.postgres = {
        enable = true;
        initialDatabases = [
          {
            name = "luanox";
            inherit user pass;
          }
        ];
        listen_addresses = "127.0.0.1,localhost";
        port = lib.toIntBase10 config.env.DATABASE_PORT;
    };

    tasks = {
      "luanox:setupHex" = {
          exec = "mix local.hex --force --if-missing";
          before = [ "devenv:enterShell" "devenv:enterTest" ];
      };
      "luanox:getDependencies" = {
          exec = "cd ${config.env.DEVENV_ROOT}/luanox; mix deps.get";
          status = "test -d ${config.env.DEVENV_ROOT}/luanox/deps";
          before = [ "devenv:enterShell" "devenv:enterTest" ];
          after = [ "luanox:setupHex" ];
      };
      "luanox:getJSDependencies" = {
          exec = "yarn --cwd ${config.env.DEVENV_ROOT}/luanox/assets";
          status = "test -d ${config.env.DEVENV_ROOT}/luanox/assets/node_modules";
          before = [ "devenv:enterShell" "devenv:enterTest" ];
      };
      "luanox-verifier:getDependencies" = {
          exec = "cd ${config.env.DEVENV_ROOT}/luanox-rockspec-verifier; mix deps.get";
          status = "test -d ${config.env.DEVENV_ROOT}/luanox-rockspec-verifier/deps";
          before = [ "devenv:enterShell" "devenv:enterTest" ];
          after = [ "luanox:setupHex" ];
      };
    };

    processes.luanox.exec = ''
      cd ${config.env.DEVENV_ROOT}/luanox
      mix phx.server
    '';

    processes.luanox-rockspec-verifier.exec = ''
      cd ${config.env.DEVENV_ROOT}/luanox-rockspec-verifier
      mix phx.server
    '';

    # enterTest = ''
    #   cd ${config.env.DEVENV_ROOT}/luanox
    #   mix test
    #   cd ${config.env.DEVENV_ROOT}/luanox-rockspec-verifier
    #   mix test
    # '';
}
