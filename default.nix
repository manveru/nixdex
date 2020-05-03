{ prefixes ? [
  "_"
  "a"
  "b"
  "c"
  "d"
  "e"
  "f"
  "g"
  "h"
  "i"
  "j"
  "k"
  "l"
  "m"
  "n"
  "o"
  "p"
  "q"
  "r"
  "s"
  "t"
  "u"
  "v"
  "w"
  "x"
  "y"
  "z"
] }:
let
  pkgs = import ./nix { };

  euphenix = pkgs.euphenix.extend (self: super: {
    parseMarkdown =
      super.parseMarkdown.override { flags = { prismjs = true; }; };
  });

  inherit (euphenix.lib)
    take optionalString hasPrefix concatMapStrings mapAttrs' concatMapStringsSep
    concatStringsSep removePrefix;
  inherit (builtins) length typeOf isString isList isAttrs;
  inherit (euphenix) build mkPostCSS cssTag;

  mkRoute = template:
    { title, pkg ? { }, ... }@extraVariables: {
      template = [ ./templates/layout.html template ];
      variables = rec {
        active = route: prefix:
          optionalString (hasPrefix prefix route) "active";
        liveJS = optionalString (__getEnv "LIVEJS" != "")
          ''<script src="/js/live.js"></script>'';
        css = cssTag (mkPostCSS ./css);
        favicon = size: ''
          <link
            rel="apple-touch-icon-precomposed"
            sizes="${toString size}x${toString size}"
            href="/favicons/favicon${toString size}.png"
          />
        '';
        favicons = concatMapStrings favicon;
        background = class: ''<div class="background ${class}"></div>'';

        renderLicenses = concatMapStrings (license:
          if isString (license.url or false)
          && isString (license.fullName or false) then
            ''<a href="${license.url}">${license.fullName}</a>''
          else if isString license then
            logIssue "license is string" license
          else if isString (license.url or false) then
            ''<a href="${license.url}">${license.url}</a>''
          else if isString (license.fullName or false) then
            license.fullName
          else
            logIssue "license is strange" "") pkg.licenses;

        renderMaintainers = concatMapStringsSep ", " (maintainer:
          if isAttrs maintainer then
            ''<a href="mailto:${maintainer.email}">${maintainer.name}</a>''
          else
            logIssue "maintainer" "") pkg.maintainers;

        renderBuildInputs = concatMapStringsSep ", " (dep:
          if isString dep then
            ''<a href="/package/${dep}.html">${dep}</a>''
          else
            logIssue "dependencies ${typeOf dep}" "") pkg.buildInputs;

        renderNativeBuildInputs = concatMapStringsSep ", " (dep:
          if isString dep then
            ''<a href="/package/${dep}.html">${dep}</a>''
          else
            logIssue "dependencies ${typeOf dep}" "") pkg.nativeBuildInputs;

        renderPosition =
          removePrefix (toString nixpkgsToRender.path) pkg.position;

        logIssue = kind: value:
          __trace "${kind} issue at (${title}) ${pkg.position}" value;

        inherit length isString concatMapStrings concatStringsSep;
      } // extraVariables;
    };

  nixpkgsToRender = let
    sources = import ./nix/sources.nix;
    nixpkgs = import sources.nixpkgs {
      config = {
        allowBroken = true;
        allowUnfree = true;
        allowUnsupportedSystem = true;
        allowInsecurePredicate = (x: true);
        oraclejdk.accept_license = true;
        android_sdk.accept_license = true;
      };
    };
  in nixpkgs;

  packages = import ./packages.nix {
    lib = euphenix.lib;
    pkgs = nixpkgsToRender;
    prefixes = prefixes;
  };

  packageRoutes = mapAttrs' (name: pkg: {
    name = "/package/${name}.html";
    value = mkRoute ./templates/package.html ({
      title = name;
      inherit pkg;
    });
  }) packages;

in build {
  src = ./.;
  name = "NixDex";

  routes = {
    "/index.html" = mkRoute ./templates/index.html {
      title = "Index";
      packages = packages;
    };
  } // packageRoutes;

  # extraParts = [ (euphenix.copyImagesMogrify ./static/img "/img" 2000) ];
}
