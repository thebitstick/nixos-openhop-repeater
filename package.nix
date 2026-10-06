{
  lib,
  python3Packages,
  fetchFromGitHub,
}:

let
  openhop-core = python3Packages.buildPythonPackage rec {
    pname = "openhop-core";
    version = "1.1.3";
    pyproject = true;

    src = fetchFromGitHub {
      owner = "openhop-dev";
      repo = "openhop_core";
      tag = "v${version}";
      hash = "sha256-wtjkD51vHSlACaGrzobZz/S+aZk+L3SpjQSBbobNJhw=";
    };

    build-system = [ python3Packages.setuptools ];

    dependencies = with python3Packages; [
      pycryptodome
      pynacl
      pyyaml
      # openhop_core's "hardware" extra
      python-periphery
      spidev
      pyserial
      pyusb
    ];

    pythonImportsCheck = [ "openhop_core" ];
    doCheck = false;

    meta = {
      description = "Python MeshCore library with SPI LoRa radio support";
      homepage = "https://github.com/openhop-dev/openhop_core";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
    };
  };
in
python3Packages.buildPythonApplication rec {
  pname = "openhop-repeater";
  version = "1.1.4";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "openhop-dev";
    repo = "openhop_repeater";
    tag = version;
    hash = "sha256-3auqNl92roQ8I1s/BCzu22l4osqpelx1dGiZK8afLHU=";
  };

  # Version is normally derived from git tags by setuptools_scm.
  env.SETUPTOOLS_SCM_PRETEND_VERSION = version;

  build-system = with python3Packages; [
    setuptools
    setuptools-scm
    wheel
  ];

  dependencies =
    (with python3Packages; [
      pyyaml
      cherrypy
      cherrypy-cors
      paho-mqtt
      psutil
      pyserial
      pyjwt
      ws4py
      rrdtool
    ])
    ++ [ openhop-core ];

  # Upstream pins exact versions of its own deps; nixpkgs versions differ slightly.
  pythonRelaxDeps = true;

  pythonImportsCheck = [ "repeater" ];
  doCheck = false;

  passthru = { inherit openhop-core; };

  meta = {
    description = "Lightweight MeshCore repeater daemon for Linux, built on openhop_core";
    homepage = "https://github.com/openhop-dev/openhop_repeater";
    license = lib.licenses.mit;
    mainProgram = "openhop-repeater";
    platforms = lib.platforms.linux;
  };
}
