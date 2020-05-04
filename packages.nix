{ lib, pkgs }:
let
  inherit (lib)
    hasAttr flatten mapAttrsToList isDerivation mapAttrs hasPrefix head filter
    drop;
  inherit (builtins)
    tryEval typeOf isList isString listToAttrs isAttrs concatStringsSep;

  packagesWith = path: cond: return: set:
    (flatten (mapAttrsToList (name: pkg:
      let
        result = tryEval (if (isDerivation pkg) && (cond name pkg) then
          [ (return (path ++ [ name ]) pkg) ]
        else if pkg.recurseForDerivations or false
        || pkg.recurseForRelease or false then
          packagesWith (path ++ [ name ]) cond return pkg
        else
          [ ]);
      in if result.success then result.value else [ ]) set));

  hasDescription = pkg: isString pkg.meta.description or null;
  hasHomepage = pkg: isString pkg.meta.homepage or null;
  hasLicense = pkg: let l = pkg.meta.license or null; in isAttrs l || isList l;
  hasMeta = pkg: isAttrs pkg.meta or null;
  hasPosition = pkg: isString pkg.meta.position or null;
  hasVersion = pkg: isString pkg.meta.version or null;

  packageFilter = name: pkg: hasPrefix "a" name;
  # let inherit (pkg.meta) description position version;
  # in isString description;

  # hasMeta pkg && hasVersion pkg && hasHomepage pkg && hasDescription pkg && hasLicense pkg && hasPosition pkg;

  packagesWithMeta = packagesWith [ ] packageFilter (path: pkg: {
    attrName = path;

    position = let try = tryEval ( pkg.meta.position or null );
               in if try.success && isString try.value then try.value else "";

    homepage = let try = tryEval (pkg.meta.homepage or null);
    in if try.success && isString try.value then try.value else "";

    version = let try = tryEval (pkg.meta.version or null);
    in if try.success && isString try.value then try.value else "";

    name = let try = tryEval (pkg.meta.name or null);
    in if try.success && isString try.value then
      try.value
    else
      (concatStringsSep "." path);

    description = let try = tryEval (pkg.meta.descritpion or null);
    in if try.success && isString try.value then try.value else "";

    licenses = let try = tryEval (pkg.meta.license or null);
               in
                 if try.success then
                   if isList try.value then try.value
                   else if isAttrs try.value then [ try.value ]
                   else if isString try.value then [ { fullName = try.value; } ]
                   else []
                 else [];

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
