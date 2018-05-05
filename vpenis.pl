#!/usr/bin/perl -w
use strict;
use warnings;

###
###   vpenis.pl  -- perl-rewrite of   http://linuxfi.org/vpenis.sh
###                 original program understood only Linux, this has
###                 learned also about Solaris ...
###
###                 2016 https://github.com/neechbear/vpenis

my $in;
my $MHz     = 0.0;
my $disk_kB = 0;
my $mem_kB  = 0;
my $ok      = 0;

my $uname_s = `uname -s`;
chomp($uname_s);

my $uptime_d = `uptime`;
chomp($uptime_d);
if ( $uptime_d =~ /up (\d+) days/ ) {
    $uptime_d = $1;
}
else {
    # If the system has been up for less than one day we could hit this
    print "WARNING: Uptime format not recognised, or up for less than a day. Assuming 1 day\n";
    $uptime_d = 1;
}
# printf "uname-s = '%s'   uptime = '%s'\n", $uname_s, $uptime_d;

###############################################################################
# BSD

if (   $uname_s eq 'NetBSD'
    || $uname_s eq 'FreeBSD'
    || $uname_s eq 'OpenBSD'
    || $uname_s eq 'Darwin' )
{
    # NetBSD tested, others PRESUMED to work..
    # Darwin doesn't tell CPU MHzs in dmesg, but ...

    # Sum of CPU MHz values, no attention at how much work per MHz gets done..
    open( $in, '-|', 'dmesg|egrep \'^cpu.* MHz, \'' );
    while (<$in>) {
        chomp;
        if (m/ ([0-9.]+) MHz/o) {
            $MHz += $1;
        }
    }
    close $in;

    # Darwin doesn't tell MHz numbers in dmesg..
    my $cpufmax = 0;
    open( $in, '-|', 'sysctl -n hw.cpufrequency_max' );
    while (<$in>) {
        chomp;
        $cpufmax = $_;
    }
    close($in);

    my $cpuf = 0;
    open( $in, '-|', 'sysctl -n hw.cpufrequency' );
    while (<$in>) {
        chomp;
        $cpuf = $_;
    }
    close($in);

    my $ncpu = 0;
    open( $in, '-|', 'sysctl -n hw.ncpu' );
    while (<$in>) {
        chomp;
        $ncpu = $_;
    }
    close($in);

    $ncpu = 1        if ( $ncpu < 1 );
    $cpuf = $cpufmax if ( $cpuf < $cpufmax );

    if ( $cpuf > 0 && $MHz < 1 ) {
        $MHz = ( $ncpu * $cpuf ) / 1000000;
    }

    #printf "MHz: %ld\n",$MHz;

    # Note: Original shows USED memory, but it isn't so easily available
    #       in e.g. Solaris, so this is TOTAL memory
    open( $in, '-|', 'sysctl -n hw.physmem' );
    while (<$in>) {
        $mem_kB += ( $_ / 1024.0 );
    }
    close($in);

    #printf "mem_kB: %ld\n",$mem_kB;

    my $dsk_dev        = 0;
    my $partition_size = 0;
    open( $in, '-|', 'df -k -l' );
    while (<$in>) {
        chomp;
        next if ( $_ =~ m/^Filesyst/o );
        if ( $_ =~ m/^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/o ) {
            $dsk_dev        = $1;
            $partition_size = $2;
            $disk_kB += $partition_size;

            # Some disk systems are given extra credit...
            if ( $dsk_dev =~ m!/dev/md!o ) {
                $disk_kB += $partition_size;
            }
        }
    }
    close $in;

    #printf "disk_kB: %ld\n",$disk_kB;

    $ok = 1;
}

###############################################################################
# SunOS

if ( $uname_s eq 'SunOS' ) {

    # Solaris understood, SunOS 4 not so...

    # Sum of CPU MHz values, no attention at how much work per MHz gets done..
    open( $in, '-|', 'psrinfo -v | grep MHz | awk \'{print $6}\'' );
    while (<$in>) {
        chomp;
        $MHz += $_;
    }
    close $in;

    #printf "MHz: %ld\n",$MHz;

    # Note: Original shows USED memory, but it isn't so easily available
    #       in e.g. Solaris, so this is TOTAL memory
    open( $in, '-|', 'prtconf | egrep \'^Memory\' | awk \'{print $3}\'' );
    while (<$in>) {
        $mem_kB += ( 1024 * $_ );
    }
    close($in);

    #printf "mem_kB: %ld\n",$mem_kB;

    open( $in, '-|', 'df -k -l' );
    my $dsk_dev        = 0;
    my $partition_size = 0;
    while (<$in>) {
        chomp;
        next if ( $_ =~ m/^Filesyst/o );
        if ( $_ =~ m/^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/o ) {
            $dsk_dev        = $1;
            $partition_size = $2;
            $disk_kB += $partition_size;

            # Some disk systems are given extra credit...
            if ( $dsk_dev =~ m!/dev/md!o ) {
                $disk_kB += $partition_size;
            }
        }
    }
    close $in;

    #printf "disk_kB: %ld\n",$disk_kB;

    $ok = 1;
}

###############################################################################
# Linux

if ( $uname_s eq 'Linux' ) {

    open( $in, '-|',
        'cat /proc/cpuinfo | grep \'^cpu MHz\' | awk \'{print $4;}\'' );
    while (<$in>) {
        chomp;
        $MHz += $_;
    }
    close $in;

    #printf "MHz: %ld\n",$MHz;

    open( $in, '-|', 'free | grep ^Mem | awk \'{print $2}\'' );
    while (<$in>) {
        $mem_kB += $_;
    }
    close $in;

    #printf "mem_kB: %ld\n",$mem_kB;

    # Note: Original shows USED memory, but it isn't so easily available
    #       in e.g. Solaris, so this is TOTAL memory

    my $dsk_dev        = 0;
    my $partition_size = 0;
	local $ENV{LANG}='C';
    open( $in, '-|', 'df -k -l' );
    while (<$in>) {
        chomp;
        next if ( $_ =~ m/^Filesyst/o );
        if ( $_ =~ m/^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/o ) {
            $dsk_dev        = $1;
            $partition_size = $2;
            $disk_kB += $partition_size;

            # Some disk systems are given extra credit...
            if ( $dsk_dev =~ m!/dev/md!o ) {
                $disk_kB += $partition_size;
            }
            if ( $dsk_dev =~ m!/dev/sd!o ) {
                $disk_kB += $partition_size;
            }
        }
    }
    close $in;

    #printf "disk_kB: %ld\n",$disk_kB;

    $ok = 1;
}

if ( !$ok ) {
    printf "SYSTEM NOT KNOWN:  uname_s = '%s'\n", $uname_s;
    exit 64;
}

my $vpenis =
  0.1 *
  ( 0.1 * $uptime_d +
      $MHz / 30.0 +
      $mem_kB / 1024.0 / 3.0 +
      $disk_kB / 1024.0 / 50.0 / 15.0 +
      70.0 );

printf "%.1fcm\n", $vpenis;

exit 0;

#### ORIGINAL vpenis.sh  SCRIPT WITH SOME ADDED WHITE-SPACE:
#
# #!/bin/sh
# echo `
#    uptime | grep days | sed 's/.*up \([0-9]*\) day.*/\1\/10+/';
#    cat /proc/cpuinfo|grep '^cpu MHz'|awk '{print $4"/30 +";}';
#    free|grep '^Mem'|awk '{print $3"/1024/3+"}';
#    df -P -k -x nfs -x smbfs | grep -v '(1k|1024)-blocks' |
#        awk '{if ($1 ~ "/dev/(scsi|sd)"){ s+= $2} s+= $2;} END {print s/1024/50"/15+70";}'
#  ` | bc | sed 's/\(.$\)/.\1cm/'
#
