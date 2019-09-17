#!/usr/bin/perl
use strict;
use warnings;

# A script for quickly creating new Vservers for a Linux-Vserver system
# running on Ubuntu using rsync method from local host.

# Version 0.5.1 (27. January 2014)

my $distrib     = 'precise';              # 12.04 Precise Pangolin LTS

my $vserverpath = '/var/lib/vservers';
my $debootstrap = '/usr/share/debootstrap/scripts';
my $vserverbin  = '/sbin/vserver';

if (!$ARGV[0] || $ARGV[0] eq '--help') {
    die("Need at least one argument (vserver name)! Usage:\n ./newvserver.pl [name] [IP]\n");
}

my $ip = '';

if ($ARGV[1]) {
    $ip = $ARGV[1];
}

# Check that we have a debootstrap script.
if ($distrib eq '' || !-f "$debootstrap/$distrib") {
    die("Unable to find a suitable bootstrap script. Please check debootstrap installation and distrib parameter.\n");
}

# Check that a vserver with this name is not already running.
my $output = `vserver-stat | grep $ARGV[0]\$`;

if ($output ne '') {
    print "Vserver with name '$ARGV[0]' already running! Stop vserver? [y/N] ";
    my $choice = <STDIN>;
    chop($choice);

    if ($choice eq 'Y' || $choice eq 'y') {
        print "Attempting to stop vserver $ARGV[0].\n";
        `$vserverbin $ARGV[0] stop`;
    } else {
        print "Not stopping vserver. Aborting.\n";
        exit();
    }
}

# Check if vserver path exists.
if (-e "$vserverpath/$ARGV[0]") {
    print "$vserverpath/$ARGV[0] already exists! Move $vserverpath/$ARGV[0] to $vserverpath/$ARGV[0].old? [y/N] ";
    my $choice = <STDIN>;
    chop($choice);

    if ($choice eq 'Y' || $choice eq 'y') {
        print "Attempting to move old vserver files out of the way.\n";
        `mv $vserverpath/$ARGV[0] $vserverpath/$ARGV[0].old`;

        if (-e "$vserverpath/$ARGV[0]") {
            print "Move seems to have failed. Aborting.\n";
            exit();
        }
    } else {
        print "Not moving old vserver files. Aborting '$choice'.\n";
        exit();
    }
}


# Check if configuration files with this name exist.
if (-e "/etc/vservers/$ARGV[0]") {
    print "Configuration files found in /etc/vservers/$ARGV[0]. Move them to /etc/vservers/$ARGV[0].old? [y/N] ";
    my $choice = <STDIN>;
    chop($choice);

    if ($choice eq 'Y' || $choice eq 'y') {
        print "Attempting to move old configuration files.\n";
        `mv /etc/vservers/$ARGV[0] /etc/vservers/$ARGV[0].old`;

        if (-e "/etc/vservers/$ARGV[0]") {
            print "Move seems to have failed. Aborting.\n";
            exit();
        }
    } else {
        print "Not moving old configuration files. Aborting.\n";
        exit();
    }
}

# Install base distribution.
print "Installing base distribution.\n";
system("$vserverbin $ARGV[0] build -m rsync -n $ARGV[0] --hostname $ARGV[0] --interface eth0:$ip -- --source /var/chroot/$distrib-minbase") == 0 or die('Error building vserver! Aborting.');
# Symlink IP to hostname for quick reference.
if ($ip ne '' && !-l "$vserverpath/$ip") {
    print "Symlinking $ip to $ARGV[0]\n";
    chdir($vserverpath);
    system("ln -s $ARGV[0]/ $ip");
}

# Generate hosts.
system("echo '$ip\t$ARGV[0]' >> $vserverpath/$ARGV[0]/etc/hosts");
system("echo '$ip' >> /etc/vservers/$ARGV[0]/interfaces/0/ip");
system("echo '32' >> /etc/vservers/$ARGV[0]/interfaces/0/prefix");
system("rm /etc/vservers/$ARGV[0]/interfaces/0/dev");
system("touch /etc/vservers/$ARGV[0]/interfaces/0/nodev");
system("echo plain > /etc/vservers/$ARGV[0]/apps/init/style");

# Generate sources.list for APT.
system("echo 'deb http://de.archive.ubuntu.com/ubuntu/ $distrib main restricted universe multiverse' > $vserverpath/$ARGV[0]/etc/apt/sources.list");
system("echo 'deb http://de.archive.ubuntu.com/ubuntu/ $distrib-updates main restricted' >> $vserverpath/$ARGV[0]/etc/apt/sources.list");
system("echo 'deb http://de.archive.ubuntu.com/ubuntu/ $distrib-backports main restricted universe multiverse' >> $vserverpath/$ARGV[0]/etc/apt/sources.list");
system("echo 'deb http://security.ubuntu.com/ubuntu $distrib-security main restricted' >> $vserverpath/$ARGV[0]/etc/apt/sources.list");

print "All done! Start the newly created vserver now? [Y/n] ";
my $choice = <STDIN>;
chop($choice);

if ($choice ne 'N' && $choice ne 'n') {
    print "Attempting to start vserver $ARGV[0].\n";
    my @args = ($vserverbin, $ARGV[0], "start");
    system(@args) == 0 or die "Unable to start vserver: $?"
}