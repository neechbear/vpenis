#!/usr/bin/perl

###
###   vpenis.pl  -- perl-rewrite of   http://linuxfi.org/vpenis.sh
###                 original program understood only Linux, this has
###                 learned also about Solaris ...
###
###

$uname_s = `uname -s`;  chomp($uname_s);

$uptime_d = `uptime`; chomp($uptime_d);

$uptime_d =~ s/.* up ([0-9]+) day.*/\1/;

# printf "uname-s = '%s'   uptime = '%s'\n",$uname_s, $uptime_d;

$ok = 0;

if ($uname_s eq 'NetBSD' || $uname_s eq 'FreeBSD' || $uname_s eq 'OpenBSD' ||
    $uname_s eq 'Darwin') {
    # NetBSD tested, others PRESUMED to work..
    # Darwin doesn't tell CPU MHzs in dmesg, but ...

    # Sum of CPU MHz values, no attention at how much work per MHz gets done..
    $MHz = 0.0;
    open(IN, 'dmesg|egrep \'^cpu.* MHz, \' |');
    while (<IN>) {
	chomp;
	if (m/ ([0-9.]+) MHz/o) {
	    $MHz += $1;
	}
    }
    close IN;

    # Darwin doesn't tell MHz numbers in dmesg..
    $cpufmax = 0;
    open(IN, 'sysctl -n hw.cpufrequency_max |');
    while (<IN>) {
	chomp;
	$cpufmax = $_;
    }
    close(IN);

    $cpuf = 0;
    open(IN, 'sysctl -n hw.cpufrequency |');
    while (<IN>) {
	chomp;
	$cpuf = $_;
    }
    close(IN);

    $ncpu = 0;
    open(IN, 'sysctl -n hw.ncpu |');
    while (<IN>) {
	chomp;
	$ncpu = $_;
    }
    close(IN);

    $ncpu = 1 if ($ncpu < 1);
    $cpuf = $cpufmax if ($cpuf < $cpufmax);

    if ($cpuf > 0 && $MHz < 1) {
	$MHz = ($ncpu * $cpuf) / 1000000;
    }

#printf "MHz: %ld\n",$MHz;

    # Note: Original shows USED memory, but it isn't so easily available
    #       in e.g. Solaris, so this is TOTAL memory
    $mem_kB = 0;
    open(IN, 'sysctl -n hw.physmem |');
    while (<IN>) {
	$mem_kB += ($_ / 1024.0);
    }
    close(IN);

#printf "mem_kB: %ld\n",$mem_kB;

    $disk_kB = 0;
    open(IN, 'df -k -l |');
    while (<IN>) {
	chomp;
	next if ($_ =~ m/^Filesyst/o);
	if ($_ =~ m/^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/o) {
	    $dsk_dev = $1;
	    $disk_kB += $2;

	    # Some disk systems are given extra credit...
	    if ($dsk_dev =~ m!/dev/md!o) {
		$disk_kB += $2;
	    }
	}
    }
    close IN;

#printf "disk_kB: %ld\n",$disk_kB;

    $ok = 1;
}


if ($uname_s eq 'SunOS') {
    # Solaris understood, SunOS 4 not so...

    # Sum of CPU MHz values, no attention at how much work per MHz gets done..
    $MHz = 0.0;
    open(IN, 'psrinfo -v | grep MHz | awk \'{print $6}\' |');
    while (<IN>) {
	chomp;
	$MHz += $_;
    }
    close IN;

#printf "MHz: %ld\n",$MHz;

    # Note: Original shows USED memory, but it isn't so easily available
    #       in e.g. Solaris, so this is TOTAL memory
    $mem_kB = 0;
    open(IN, 'prtconf | egrep \'^Memory\' | awk \'{print $3}\' |');
    while (<IN>) {
	$mem_kB += (1024 * $_);
    }
    close(IN);

#printf "mem_kB: %ld\n",$mem_kB;

    $disk_kB = 0;
    open(IN, 'df -k -l |');
    while (<IN>) {
	chomp;
	next if ($_ =~ m/^Filesyst/o);
	if ($_ =~ m/^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/o) {
	    $dsk_dev = $1;
	    $disk_kB += $2;

	    # Some disk systems are given extra credit...
	    if ($dsk_dev =~ m!/dev/md!o) {
		$disk_kB += $2;
	    }
	}
    }
    close IN;

#printf "disk_kB: %ld\n",$disk_kB;

    $ok = 1;
}

if ($uname_s eq 'Linux') {

    $MHz = 0;
    open(IN, 'cat /proc/cpuinfo | grep \'^cpu MHz\' | awk \'{print $4;}\' |');
    while (<IN>) {
	chomp;
	$MHz += $_;
    }
    close IN;

#printf "MHz: %ld\n",$MHz;

    $mem_kB = 0.0;
    open(IN, 'free | grep ^Mem | awk \'{print $2}\' |');
    while (<IN>) {
	$mem_kB += $_;
    }
    close IN;

#printf "mem_kB: %ld\n",$mem_kB;

    # Note: Original shows USED memory, but it isn't so easily available
    #       in e.g. Solaris, so this is TOTAL memory

    $disk_kB = 0;
    open(IN, 'df -k -l |');
    while (<IN>) {
	chomp;
	next if ($_ =~ m/^Filesyst/o);
	if ($_ =~ m/^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/o) {
	    $dsk_dev = $1;
	    $disk_kB += $2;

	    # Some disk systems are given extra credit...
	    if ($dsk_dev =~ m!/dev/md!o) {
		$disk_kB += $2;
	    }
	    if ($dsk_dev =~ m!/dev/sd!o) {
		$disk_kB += $2;
	    }
	}
    }
    close IN;

#printf "disk_kB: %ld\n",$disk_kB;

    $ok = 1;
}

if (!$ok) {
    printf "SYSTEM NOT KNOWN:  uname_s = '%s'\n",$uname_s;
    exit 64;
}

$vpenis = 0.1 * (
		 0.1 * $uptime_d +
		 $MHz / 30.0 +
		 $mem_kB / 1024.0 / 3.0 +
		 $disk_kB / 1024.0 / 50.0 / 15.0 +
		 70.0);

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
