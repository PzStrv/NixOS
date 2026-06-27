{
  description = "mi config";

  inputs = {
	nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

	home-manager = {
	  url = "github:nix-community/home-manager";
	  inputs.nixpkgs.follows = "nixpkgs";
	};
  };

  outputs = { self, nixpkgs, home-manager, ... }: {
	nixosConfigurations.pingo = nixpkgs.lib.nixosSystem {
	  system = "x86_64-linux";
	  modules = [
		/etc/nixos/configuration.nix
		home-manager.nixosModules.home-manager
		{
		  home-manager.useGlobalPkgs = true;
		  home-manager.useUserPackages = true;
		  home-manager.users.maj = import /etc/nixos/home/maj.nix;
		}
	  ];
	};
  };
}

