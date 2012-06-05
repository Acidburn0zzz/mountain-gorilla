#!/usr/bin/bash

# removes old files and attempts to restore the machine to a
# consistent (clean) state. It removes known sensitive files.

cleanup() {

  # clean up old log files
  echo "==> removing tmp and log files"
  rm -rf /var/svc/log/*
  find /var/log -type f | xargs rm -f
  find /var/adm -type f | xargs rm -f
  find /var/db/pkgin -type f | xargs rm -f
  find /var/cron -type f | xargs rm -f
  rm -f /var/spool/postfix/deferred/*

  # touch necessary log files 
  touch /var/adm/wtmpx

  # unset passwords that may have been mistakenly left
  echo "==> unsetting 'root' and 'admin' passwords"
  out=$(passwd -N root)
  out=$(passwd -N admin)

  # remove old ssh keys
  echo "==> removing old ssh host keys"
  rm -f /etc/ssh/ssh_*key*

  echo "==> cleaning up old network configuration"
  # remove old network configuration files
  echo "::1        localhost"          > /etc/hosts 
  echo "127.0.0.1  localhost loghost" >> /etc/hosts 

  # interface configuration files
  find /etc/hostname.net* | xargs rm -f
  
  # remove zoneconfig
  rm /root/zoneconfig
}

cleanup
