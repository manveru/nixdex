{ prefixes, lib, pkgs }:
let
  inherit (lib)
    hasAttr flatten mapAttrsToList isDerivation mapAttrs hasPrefix head filter
    drop;
  inherit (builtins) tryEval typeOf isList isString listToAttrs isAttrs;

  # unique = f: list:
  #   if list == [ ] then
  #     [ ]
  #   else
  #     let
  #       x = head list;
  #       xs = filter (p: f x != f p) (drop 1 list);
  #     in [ x ] ++ unique f xs;

  packagesWith = path: cond: return: set:
    (flatten (mapAttrsToList (name: pkg:
      let
        result = tryEval (if (isDerivation pkg) && (cond name pkg) then
          [ (return (path ++ [name]) pkg) ]
        else if pkg.recurseForDerivations or false
        || pkg.recurseForRelease or false then
          packagesWith (path ++ [name]) cond return pkg
        else
          [ ]

        );
      in if result.success then result.value else [ ]) set));

  hasMeta = pkg: isAttrs pkg.meta or null;
  hasVersion = pkg: isString pkg.version or null;
  hasDescription = pkg: isString pkg.meta.description or null;
  hasHomepage = pkg: isString pkg.meta.homepage or null;
  hasLicense = pkg: let l = pkg.meta.license or null; in isAttrs l || isList l;
  hasPosition = pkg: isString pkg.meta.position or null;

  packageFilter = name: pkg:
    (lib.any (p: hasPrefix p name) prefixes)
     && hasMeta pkg && hasVersion pkg && hasHomepage pkg
    && hasDescription pkg && hasLicense pkg && hasPosition pkg;

  packagesWithMeta = packagesWith [] packageFilter (path: pkg: {
    attrName = path;
    inherit (pkg) name version;
    inherit (pkg.meta) homepage description position;

    longDescription = let
      tryLD = tryEval (pkg.meta.longDescription or null);
      ld = tryLD.value;
    in if tryLD.success && isString ld then ld else null;

    buildInputs = let
      tryDeps = tryEval (flatten pkg.buildInputs);
      deps = tryDeps.value;
    in if tryDeps.success && isList deps then
      map (dep:
        let tryName = tryEval (toString dep.name);
        in if isAttrs dep && tryName.success then tryName.value else null) deps
    else
      [ ];

    nativeBuildInputs = let
      tryDeps = tryEval (flatten pkg.nativeBuildInputs);
      deps = tryDeps.value;
    in if tryDeps.success && isList deps then
      map (dep:
        let tryName = tryEval (toString dep.name);
        in if isAttrs dep && tryName.success then tryName.value else null) deps
    else
      [ ];

    licenses = if isList pkg.meta.license then
      flatten pkg.meta.license
    else
      [ pkg.meta.license ];

    maintainers = if isList (pkg.meta.maintainers or false) then
      flatten pkg.meta.maintainers
    else if isAttrs (pkg.meta.maintainers or false) then
      [ pkg.meta.maintainers ]
    else
      [ ];
  }) pkgs;
in listToAttrs (map (pkg: {
  name = pkg.name;
  value = pkg;
}) packagesWithMeta)
