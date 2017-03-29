# TunnelDeli
A server-client combination script to simplify various tunneling techniques.

[Warning]:
These scripts come as-is with no promise of functionality or accuracy.  I strictly wrote them for personal use.  I have no plans to maintain updates, I did not write them to be efficient and in some cases you may find the functions may not produce the desired results so use at your own risk/discretion.  I wrote these scripts to target machines in a lab environment so please only use it against systems for which you have permission!!

[Modification, Distribution, and Attribution]:
You are free to modify and/or distribute these scripts as you wish.  I only ask that you maintain original author attribution and not attempt to sell it or incorporate it into any commercial offering (as if it's worth anything anyway :)

--------------------------------------------

Usage:

1) Spin up an Ubuntu 16.04 server and run serversetup.sh to install the TunnelDeli server.
- Set password for tunneling services (should be different than server root password)
- Set subdomain of server's domain for iodine (tunnel.mydomain.com)
- Open necessary ports on firewall

2) Run tunneldeli.py from a kali linux distribution (with the necessary applications installed)

--------------------------------------------

Contents:

Currently, TunnelDeli supports 4 methods of tunneling:

- Straight SSH
- SSH through ICMP Packets (ptunnel)
- SSH through DNS Packets (iodine)
- SSH through TLS Packets (stunnel)
