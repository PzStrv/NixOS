{ config, ... }:

{
# Open ports in the firewall.
networking.firewall.enable = true;

networking.firewall.allowedTCPPorts = [ 22 ];
networking.firewall.allowedUDPPorts = [ 7 ];
}
