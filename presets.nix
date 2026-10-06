# Radio presets, read from radio-presets.json: an unmodified copy of openhop_repeater's file of the same
# name (MIT, see THIRD-PARTY-NOTICES.md), which mirrors the MeshCore network's settings API.
# Each preset becomes an attribute named after its title, e.g. "USA/Canada (Recommended)" is
# `usa-canada-recommended`, with the values converted to what the daemon's config expects.
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

  # "910.525" -> 910525000 and "62.5" -> 62500. Integer arithmetic on the digits, because float
  # maths would turn 869.618 MHz into 869618000.0000001 Hz.
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
    # upstream gives bytes per hop (1-3); the daemon's path_hash_mode counts from 0
    pathHashMode = if entry ? network_settings then entry.network_settings.path_hash_size - 1 else null;
  };
in
lib.listToAttrs (map (entry: lib.nameValuePair (slug entry.title) (convert entry)) entries)
