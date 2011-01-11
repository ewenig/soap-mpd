#!/usr/bin/perl

use warnings;
use strict;
use Socket::Class;
use XML::RPC;

sub get_outputs {
	my $mpd = $_[0];
	$mpd->writeline("outputs");
	my @buf;
	my @outputs;
	do {
		push(@outputs,$mpd->readline);
	} while ($outputs[-1] =~ /^output/);
	foreach my $line (@outputs) {
		$line = substr($line,index($line,' ')+1);
	}
	return @outputs;
}

sub check_status {
	my $mpd = $_[0];
	unless ($mpd->readline =~ m/^OK/) {
		die "MPD returned bad status";
	}
}

sub mpd_play {
	my ($mpd,$playlist,$random) = @_;
	$mpd->writeline("stop");
	check_status($mpd);
	$mpd->writeline("clear");
	check_status($mpd);
	$mpd->writeline("single 0");
	check_status($mpd);
	$mpd->writeline("random $random");
	check_status($mpd);
	$mpd->writeline("load $playlist");
	check_status($mpd);
	$mpd->writeline("play");
	check_status($mpd);
}

sub soap_play {
	my ($side,$room,$host,$port) = @_;
	my $soap;
	if ($side eq 'n') {
		$soap = XML::RPC->new('http://soap.csh.rit.edu:1235/RPC2');
	} elsif ($side eq 's') {
		$soap = XML::RPC->new('http://soap-south.csh.rit.edu:1235/RPC2');
	}

	$soap->call('playStream',$room,"http://$host:$port");
}

sub soap_mpd {
	my $mpd = Socket::Class->new(
		'remote_addr' => $_[0],
		'remote_port' => $_[1],
		) or die Socket::Class->error;
	my $version = $mpd->readline;
	print $version . "\n";
	
	my @outputs = get_outputs($mpd);
	
	my $i;
	for ($i=0;$i<$#outputs;$i+=3) {
		if ($outputs[$i+1] eq "SOAP") {
			$mpd->writeline("enableoutput $outputs[$i]");
		} else {
			if ($outputs[$i+2] eq "1") {
				$mpd->writeline("disableoutput $outputs[$i]");
			}
		}
	}

	mpd_play($mpd,$_[2],$_[6]);
	check_status($mpd);
	soap_play($_[3],$_[4],$_[0],$_[5]);
	$mpd->close;
	
	print "Sleeping for 15 minutes.";
	sleep(15*60);

        $mpd = Socket::Class->new(
                'remote_addr' => $_[0],
                'remote_port' => $_[1],
                ) or die Socket::Class->error;

	for ($i=0;$i<$#outputs;$i+=3) {
		if ($outputs[$i+1] eq "SOAP") {
                        $mpd->writeline("disableoutput $outputs[$i]");
                } else {
                        if ($outputs[$i+2] eq "1") {
                                $mpd->writeline("enableoutput $outputs[$i]");
                        }
                }
        }

	$mpd->close;
}

soap_mpd($ARGV[0],$ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4],$ARGV[5],$ARGV[6]);
