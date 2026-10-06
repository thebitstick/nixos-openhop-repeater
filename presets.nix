# radio-presets.json is an unmodified copy of upstream's (see THIRD-PARTY-NOTICES.md)
{ lib }:
let
  entries =
    (builtins.fromJSON (builtins.readFile ./radio-presets.json))
    .config.suggested_radio_settings.entries;

  slug =
    title:
    lib.concatStringsSep "-" (
      lib.filter (s: s != "") (lib.filter lib.isString (builtins.split "[^a-z0-9]+" (lib.toLower title)))
    );

  # Integer arithmetic on the digits: float maths turns 869.618 MHz into 869618000.0000001 Hz
  scale =
    digits: value:
    let
      parts = lib.splitString "." value;
      fraction = if lib.length parts > 1 then lib.elemAt parts 1 else "";
      padded = fraction + lib.concatStrings (lib.genList (_: "0") (digits - lib.stringLength fraction));
    in
    lib.toInt (lib.head parts + builtins.substring 0 digits padded);

  convert = entry: {
    inherit (entry) title description;
    frequency = scale 6 entry.frequency;
    bandwidth = scale 3 entry.bandwidth;
    spreadingFactor = lib.toInt entry.spreading_factor;
    codingRate = lib.toInt entry.coding_rate;
    # upstream counts bytes per hop (1-3); path_hash_mode starts at 0
    pathHashMode = if entry ? network_settings then entry.network_settings.path_hash_size - 1 else null;
  };
in
lib.listToAttrs (map (entry: lib.nameValuePair (slug entry.title) (convert entry)) entries)
