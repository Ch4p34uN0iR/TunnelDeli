#!/usr/bin/python
###################################################
#
#   TunnelDeli - written by Justin Ohneiser
# ------------------------------------------------
# This program will build a tunnel to a TunnelDeli
# server in a variety of ways.
# Requires the following services be installed:
# 	- ssh
#	- iodine
#	- ptunnel
# 	- stunnel4
#
# [Warning]:
# This script comes as-is with no promise of functionality or accuracy.  I strictly wrote it for personal use
# I have no plans to maintain updates, I did not write it to be efficient and in some cases you may find the
# functions may not produce the desired results so use at your own risk/discretion. I wrote this script to
# target machines in a lab environment so please only use it against systems for which you have permission!!
#-------------------------------------------------------------------------------------------------------------
# [Modification, Distribution, and Attribution]:
# You are free to modify and/or distribute this script as you wish.  I only ask that you maintain original
# author attribution and not attempt to sell it or incorporate it into any commercial offering (as if it's
# worth anything anyway :)
#
# Designed for use in Kali Linux 4.9.0-kali3-amd64
###################################################

import os, sys, getopt, subprocess, time, collections, getpass

Tuple = collections.namedtuple("Tuple", ["t","p"])
CLEANUP = []

def printUsage():
  print("TunnelDeli v1.0")
  print("Usage: %s -m <mode> <server>" % sys.argv[0])
  print("    Modes: %s" % KNOWN_MODES.keys())

def printC(i,m):
  if i == 0: print("[*] %s" % m)
  elif i == 1: print("\033[91m[!] %s\033[0m" % m)
  elif i == 2: print("\033[93m[-] %s\033[0m" % m)
  elif i == 3: print("\033[92m[+] %s\033[0m" % m)
  elif i == 4: print("\033[94m[?] %s\033[0m" % m)

def printH():
  print("===============================================")
  print("   __                         ______       ___ ")
  print("  / /___  ______  ____  ___  / / __ \___  / (_)")
  print(" / __/ / / / __ \/ __ \/ _ \/ / / / / _ \/ / / ")
  print("/ /_/ /_/ / / / / / / /  __/ / /_/ /  __/ / /  ")
  print("\__/\__,_/_/ /_/_/ /_/\___/_/_____/\___/_/_/   ")
  print("                                               ")
  print("v1.0           [Tested: kali 4.9.0-kali3-amd64]")
  print("===============================================")

# ------------------------------------
#       Modes
# ------------------------------------

def ssh(tuple):
  if tuple == 0:
    return 22
  if tuple == -1:
    printC(2,"Cancelling tunnel...")
    return -1
  target = tuple[0]
  port = tuple[1]
  if port == 0:
    port = 22
  ssh_handle = "~/.ssh-tunnel-%s" % target
  lport = 9001
  printC(0,"Building tunnel...")
  cmd = "ssh root@%s -p %s -N -D %s -f -M -S '%s'" % (target, port, lport, ssh_handle)
  try:
    subprocess.check_call(cmd, shell=True)
    printC(3,"Tunnel built - Set SOCKS proxy to 127.0.0.1:%s" % (lport))
    CLEANUP.append("ssh -S %s -O exit root@%s" % (ssh_handle, target))
    print("([Ctrl-C to exit])")
    while True:
      time.sleep(5)
      subprocess.check_call("ssh -S %s -O check root@%s 2>/dev/null" % (ssh_handle, target), shell=True)
  except subprocess.CalledProcessError as e:
    printC(1,"An error has occurred: %s" % e)
  except KeyboardInterrupt:
    print("")
    printC(0,"Exiting")

def icmp(tuple):
  if tuple == 0:
    return 0
  if tuple == -1:
    printC(2,"Cancelling tunnel...")
    return -1
  server = tuple[0]
  port = tuple[1]
  if port == 0:
    port = ssh(0)
  lport = 9000
  puser = "proxy"
  pgroup = "proxy"
  pid = "/tmp/ptunnel_pid"
  log = "/var/log/ptunnel.log"
  password = getpass.getpass(prompt="Enter password: ")
  printC(0,"Building ICMP wrapper...")
  cmd = "ptunnel -p %s -lp %s -da 127.0.0.1 -dp %s -x %s -daemon %s -f %s -v 4 -setuid %s -setgid %s" % (server, lport, port, password, pid, log, puser, pgroup)
  try:
    subprocess.check_call(cmd, shell=True)
    printC(3,"ICMP wrapper built.")
    CLEANUP.append("kill $(cat %s 2>/dev/null) 2>/dev/null || killall ptunnel 2>/dev/null & rm %s" % (pid,pid))
  except subprocess.CalledProcessError as e:
    printC(1,"An error has occurred: %s" % e)
    return -1
  time.sleep(1)
  return ssh(Tuple("127.0.0.1",lport))

def dns(tuple):
  if tuple == 0:
    return 0
  if tuple == -1:
    printC(2,"Cancelling tunnel...")
    return -1
  server = tuple[0]
  port = tuple[1]
  if port == 0:
    port = ssh(0)
  lip = "10.9.8.1"
  lport = 22
  dns = "8.8.8.8"
  iuser = "iodine"
  pid = "/tmp/iodine_pid"
  printC(0,"Building DNS wrapper...")
  cmd = "iodine -u %s -F %s %s %s" % (iuser, pid, dns, server)
  try:
    subprocess.check_call(cmd, shell=True)
    printC(3, "DNS wrapper built.")
    CLEANUP.append("kill $(cat %s 2>/dev/null) 2>/dev/null || killall iodine 2>/dev/null & rm %s" % (pid,pid))
  except subprocess.CalledProcessError as e:
    printC(1,"An error has occurred: %s" % e)
    return -1
  time.sleep(1)
  return ssh(Tuple(lip,lport))

def https(tuple):
  if tuple == 0:
    return 443
  if tuple == -1:
    printC(2,"Cancelling tunnel...")
    return -1
  server = tuple[0]
  port = tuple[1]
  if port == 0:
    port = 443
  lport = 9000
  pid = "/tmp/stunnel_pid"
  printC(0,"Building HTTPS wrapper...")
  file = open("/etc/stunnel/stunnel.conf","w")
  file.truncate()
  file.write("client=yes\n")
  file.write("pid=%s\n" % pid)
  file.write("[https]\n")
  file.write("accept=127.0.0.1:%s\n" % lport)
  file.write("connect=%s:%s\n" % (server,port))
  file.close()
  cmd = "stunnel"
  try:
    subprocess.check_call(cmd, shell=True)
    printC(3, "HTTPS wrapper built.")
    CLEANUP.append("kill $(cat %s 2>/dev/null) 2>/dev/null || killall stunnel 2>/dev/null & rm %s" % (pid,pid))
  except subprocess.CalledProcessError as e:
    printC(1,"An error has occurred: %s" % e)
    return -1
  time.sleep(1)
  return ssh(Tuple("127.0.0.1",lport))

KNOWN_MODES = {
  "ssh"		:  ssh,
  "icmp"	:  icmp,
  "dns" 	:  dns,
  "https"	:  https
}

# ------------------------------------
#       Main
# ------------------------------------

def main(argv):
  MODE=""
  SERVER=""
  try:
    try:
      opts, args = getopt.getopt(argv, "hm:")
    except getopt.GetoptError:
      printUsage()
      sys.exit(2)

    if len(args) != 1:
      printUsage()
      sys.exit(2)

    SERVER = args[0]

    for opt, arg in opts:
      if opt == "-h":
        printUsage()
        sys.exit(2)
      elif opt == "-m":
        MODE = arg

    if (MODE == "") or (SERVER == ""):
      printUsage()
      sys.exit(2)

    if MODE not in KNOWN_MODES:
      printC(2,"Mode not found: %s" % MODE)
      sys.exit(1)

    printH()

    try:
      KNOWN_MODES[MODE](Tuple(SERVER,0))
    except AttributeError as e:
      printC(1,"An error has occurred: %s" % e)
      sys.exit(1)

  except Exception as e:
    printC(1,"An error has occurred: %s" % e)
  except KeyboardInterrupt:
    print("\nExiting")
  finally:
    if CLEANUP != []:
      printC(0,"Cleaning up...")
      for cmd in CLEANUP:
        try:
          subprocess.check_call(cmd, shell=True)
        except subprocess.CalledProcessError as e:
          printC(4, "An error has occurred: %s" % e)

if __name__ == "__main__":
  main(sys.argv[1:])
