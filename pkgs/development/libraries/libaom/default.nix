{ lib, stdenv, fetchzip, yasm, perl, cmake, pkg-config, python3
, enableButteraugli ? true, libjxl
, enableVmaf ? true, libvmaf
, gitUpdater
}:

let
  isCross = stdenv.buildPlatform != stdenv.hostPlatform;
in
stdenv.mkDerivation rec {
  pname = "libaom";
  version = "3.7.0";

  src = fetchzip {
    url = "https://aomedia.googlesource.com/aom/+archive/v${version}.tar.gz";
    hash = "sha256-Zf0g/CMI73O9Dkn9o7aIvwZ/8wh3lCmVY8nZaPwBp68=";
    stripRoot = false;
  };

  patches = [ ./outputs.patch ];

  nativeBuildInputs = [
    yasm perl cmake pkg-config python3
  ];

  propagatedBuildInputs = lib.optional enableButteraugli libjxl
    ++ lib.optional enableVmaf libvmaf;

  preConfigure = ''
    # build uses `git describe` to set the build version
    cat > $NIX_BUILD_TOP/git << "EOF"
    #!${stdenv.shell}
    echo v${version}
    EOF
    chmod +x $NIX_BUILD_TOP/git
    export PATH=$NIX_BUILD_TOP:$PATH
  '';

  # Configuration options:
  # https://aomedia.googlesource.com/aom/+/refs/heads/master/build/cmake/aom_config_defaults.cmake

  cmakeFlags = [
    "-DBUILD_SHARED_LIBS=ON"
    "-DENABLE_TESTS=OFF"
  ] ++ lib.optionals enableButteraugli [
    "-DCONFIG_TUNE_BUTTERAUGLI=1"
  ] ++ lib.optionals enableVmaf [
    "-DCONFIG_TUNE_VMAF=1"
  ] ++ lib.optionals (stdenv.isDarwin && stdenv.isAarch64) [
    # CPU detection isn't supported on Darwin and breaks the aarch64-darwin build:
    "-DCONFIG_RUNTIME_CPU_DETECT=0"
  ] ++ lib.optionals (isCross && !stdenv.hostPlatform.isx86) [
    "-DAS_EXECUTABLE=${stdenv.cc.targetPrefix}as"
  ] ++ lib.optionals stdenv.isAarch32 [
    # armv7l-hf-multiplatform does not support NEON
    # see lib/systems/platform.nix
    "-DENABLE_NEON=0"
  ];

  postFixup = ''
    moveToOutput lib/libaom.a "$static"
  '' + lib.optionalString stdenv.hostPlatform.isStatic ''
    ln -s $static $out
  '';

  outputs = [ "out" "bin" "dev" "static" ];

  passthru = {
    updateScript = gitUpdater {
      url = "https://aomedia.googlesource.com/aom";
      rev-prefix = "v";
      ignoredVersions = "(alpha|beta|rc).*";
    };
  };

  meta = with lib; {
    description = "Alliance for Open Media AV1 codec library";
    longDescription = ''
      Libaom is the reference implementation of the AV1 codec from the Alliance
      for Open Media. It contains an AV1 library as well as applications like
      an encoder (aomenc) and a decoder (aomdec).
    '';
    homepage    = "https://aomedia.org/av1-features/get-started/";
    changelog   = "https://aomedia.googlesource.com/aom/+/refs/tags/v${version}/CHANGELOG";
    maintainers = with maintainers; [ primeos kiloreux dandellion ];
    platforms   = platforms.all;
    outputsToInstall = [ "bin" ];
    license = licenses.bsd2;
  };
}
