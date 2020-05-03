with import ./nix {};
pkgs.mkShell {
  buildInputs = [
    cacert
    niv
    euphenix.euphenix
  ];
  shellHook = ''
    unset preHook
  '';
}
