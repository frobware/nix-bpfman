{ lib, fetchFromGitHub, pkgs, rustPlatform, bpfmanBuildType ? "release" }:

rustPlatform.buildRustPackage rec {
  pname = "bpfman";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "bpfman";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-ccMMh1Z7A0Xo7qBXWPhzSXXS4uJ9Td1yW2VlvtGu6qE=";
  };

  cargoHash = "sha256-MOuE/zycpsxC8J4L6WWisKb5fogcBRj8ZhOS8ENpqUw=";

  buildType = bpfmanBuildType;

  # buildInputs: Include libraries or tools here that bpfman links
  # against or requires at runtime. These dependencies are used by the
  # software on the target platform where it will be executed.
  buildInputs = [
    pkgs.openssl              # Used for SSL/TLS support.
    pkgs.zlib                 # Compression library for data handling.
  ];

  # nativeBuildInputs: Include dependencies here that are necessary
  # for the build process and are executed on the build platform.
  # These tools run on the architecture where the build is taking
  # place.
  nativeBuildInputs = [
    pkgs.pkg-config     # Helps to discover compiler and linker flags.
  ];

  # Disable test execution. Nix's sandboxing will cause tests that
  # attempt to pull from the internet at execution time to fail;
  # bpfman's tests pull from the internet. Nix builds, including
  # tests, are executed in a highly controlled environment that does
  # not have network access. This is a deliberate feature to ensure
  # builds are reproducible and not affected by external changes or
  # dependencies.
  doCheck = false;

  # Remove unwanted binaries after the install phase.
  postInstall = ''
    rm -f $out/bin/integration-test
    rm -f $out/bin/xtask
  '';

  meta = with lib; {
    description = "An eBPF Manager for Linux and Kubernetes.";
    license = licenses.mit;
    mainProgram = "bpfman";
    maintainers = [ "frobware" ];
    platforms = platforms.linux;
  };
}
