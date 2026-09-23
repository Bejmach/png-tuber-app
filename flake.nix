{
  description = "Odin development";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [
		gcc
        odin
		ols

		# Add all vendor packages
		miniaudio
		raylib

		pipewire
		libpulseaudio
	  ];

	  LD_LIBRARY_PATH = with pkgs; "$LD_LIBRARY_PATH:${
		  pkgs.lib.makeLibraryPath [
			# Add all vendor packages
			miniaudio
			raylib

			pipewire
			libpulseaudio
		  ] + ":${toString ./.}/vendor/raygui"
	  }";
    };
  };
}
