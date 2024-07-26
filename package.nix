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

  doCheck = true;

  checkPhase = ''
    # Skip tests that require internet access.
    cargo test --release -- \
      --skip oci_utils::image_manager::tests::image_pull_failure \
      --skip oci_utils::image_manager::tests::image_pull_and_bytecode_verify \
      --skip oci_utils::image_manager::tests::private_image_pull_and_bytecode_verify \
      --skip oci_utils::image_manager::tests::image_pull_policy_never_failure
  '';

  # Remove unwanted binaries after the install phase.
  postInstall = ''
    rm -f $out/bin/integration-test
    rm -f $out/bin/xtask
  '';

  meta = with lib; {
    description = "An eBPF Manager for Linux and Kubernetes.";
    license = with licenses; [asl20 bsd2 gpl2];
    mainProgram = "bpfman";
    maintainers = [ "frobware" ];
    platforms = platforms.linux;
  };
}
