{ lib, fetchFromGitHub, pkgs, rustPlatform, bpfmanBuildType ? "release" }:

rustPlatform.buildRustPackage rec {
  pname = "bpfman";
  version = "0.5.6";

  src = fetchFromGitHub {
    owner = "bpfman";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-mvjrdoReEtHIm3reJBaLdbPy6SJ+BV6v/ECSe77Imxw=";
  };

  cargoHash = "sha256-ixHykJtoZ9/utHFdDGdXw22p5y4s5etDETFHLGJVeio=";

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
    pkgs.cmake
    pkgs.llvmPackages.clang
    pkgs.llvmPackages.libclang.lib
    pkgs.pkg-config
  ];

  # Set environment variables for build.
  LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";

  # Disable problematic compiler flags for aws-lc.
  NIX_CFLAGS_COMPILE = "-Wno-error=stringop-overflow";

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
