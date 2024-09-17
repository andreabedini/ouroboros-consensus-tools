{ config, modulesPath, ... }:

# General configuration to work in a systemd-nspawn container
{
  imports = [ "${modulesPath}/virtualisation/container-config.nix" ];

  boot.isContainer = true;

  networking = {
    # do not configure default networks
    useDHCP = false;

    # use systemd-networkd
    useNetworkd = true;

    # use systemd-resolved
    useHostResolvConf = false;
  };

  services.resolved.enable = true;

  systemd.network.networks."99-default" = {
    matchConfig.Name = [ "host*" ];
    networkConfig.MulticastDNS = "yes";
    DHCP = "ipv4";
    dhcpV4Config = {
      UseTimezone = "yes";
      UseDNS = "yes";
    };
  };

  # systemd-nspawn expects /sbin/init
  boot.loader.initScript.enable = true;

  # After booting, register the contents of the Nix store in the Nix database.
  boot.postBootCommands = ''
    if [ -f /nix-path-registration ]; then
      ${config.nix.package.out}/bin/nix-store --load-db < /nix-path-registration &&
      rm /nix-path-registration
    fi
  '';

  # 1. /etc/os-release cannot be a symlink to the store, because the store is mounted later on.
  # 2. /usr/lib/systemd/systemd, /lib/systemd/systemd, /sbin/init have to be present
  system.systemBuilderCommands = ''
    # Remove /etc and replace it with a real directory
    rm $out/etc
    mkdir $out/etc

    # Copy the content of /etc in /etc
    cp -r ${config.system.build.etc}/etc/* $out/etc

    # Remove /etc/os-release and replace with a copy of its content
    rm $out/etc/os-release
    cp --dereference ${config.system.build.etc}/etc/os-release $out/etc/os-release

    # Symlink /sbin/init
    mkdir $out/sbin
    ln -s ../init $out/sbin/init
  '';
}
