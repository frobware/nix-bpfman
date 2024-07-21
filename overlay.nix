final: prev: {
  bpfman = prev.callPackage ./package.nix {};
  default = final.bpfman;
}
