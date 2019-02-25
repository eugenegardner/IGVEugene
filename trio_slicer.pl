#!/usr/bin/perl

use strict;
use warnings;
use IO::Socket::INET;
use File::Basename;
use Getopt::Long;

my %args;
GetOptions(\%args,
		   "bams=s",
		   "hostname=s",
		   "port=i",
		   "window=i",
		   "slicedir=s"
	);

my ($bamFile, $hostname, $port, $window, $slicedir) = setOptions(\%args);

open (BAM, "<$bamFile") || die "Cannot open file: $!";

my $socket = new IO::Socket::INET (PeerHost => $hostname,
								   PeerPort => $port,
								   Proto => 'tcp'
	) || die "ERROR in Socket Creation or cannot connect to IGV: $!";

print "Socket connection successful.\n";

my %results;

print "Iterating through files/coordinates in -bams, type QUIT to exit and pint all information!\n\n";

foreach my $site (<BAM>) {
	
	chomp $site;
	
	my @data = split("\t", $site);
	
	my $chr = $data[3];
	my $pos = $data[4];
	my $left = $data[4] - $window;
	my $right = $data[4] + $window;
	
	my $dir = $slicedir; 

	my $proband = $data[0];
	my ($pName, $a, $b) = fileparse($proband, qr/\.[^.]*/);
	my $mum = $data[1];
	my $dad = $data[2];

	print $socket "new\n";
	print $socket "setSleepInterval 100\n";
	samtools($proband, $chr, $left, $right, "/nfs/" . $dir . "proband.$pName.$chr" . "_$pos.bam");
	print $socket "load /Volumes/$dir" . "proband.$pName.$chr" . "_$pos.bam\n";
	
	if ($mum ne "-") {
	    my ($mName, $c, $d) = fileparse($mum, qr/\.[^.]*/);
	    samtools($mum, $chr, $left, $right, "/nfs/" . $dir . "mum.$mName.$chr" . "_$pos.bam");
	    print $socket "load /Volumes/$dir" . "mum.$mName.$chr" . "_$pos.bam\n";
	}
	if ($dad ne "-") {
	    my ($dName, $c, $d) = fileparse($dad, qr/\.[^.]*/);
	    samtools($dad, $chr, $left, $right, "/nfs/" . $dir . "dad.$dName.$chr" . "_$pos.bam");
	    print $socket "load /Volumes/$dir" . "dad.$dName.$chr" . "_$pos.bam\n";
	}

	print $socket "squish\n";
	
 	print "Prob: $proband\n";
	print "P1  : $mum\n";
	print "P2  : $dad\n";

	print $socket "goto $chr:$left-$right\n";
	my $wait = <STDIN>;
	chomp $wait;
	
	$results{$chr . ":" . $pos} = $wait;

	if ($wait eq 'QUIT') {

	    dumpResults(\%results);
	    die "Aborted: $!";

	}

}

dumpResults(\%results);

sub setOptions {

	my ($opt) = @_;

	my $bamFile;
	if ($$opt{bams}) {
		$bamFile = $$opt{bams};
	} else {
		die "Need bam list file provided to -bams";
	}
	
	my $hostname;
	if ($$opt{hostname}) {
		$hostname = $$opt{hostname};
	} else {
		die "Need name of computer to connect to as -hostname";
	}

	my $slicedir;
	if ($$opt{slicedir}) {
		if (-e $$opt{slicedir} && -d $$opt{slicedir}) {
			$slicedir = $$opt{slicedir};
		} else {
			die "path provided to -slicedir either doesn't exist or is not a directory!";
		}
	} else {
		die "Need directory for -slicedir!";
	}

	my $port;
	if ($$opt{port}) {
		$port = $$opt{port};
	} else {
		print "No value for -port provided, setting to default IGV port of 60151";
		$port = 60151;
	}

	my $window;
	if ($$opt{window}) {
		$window = $$opt{window};
	} else {
		$window = 50;
	}
	
	return($bamFile, $hostname, $port, $window, $slicedir);

}
	
sub dumpResults {

    my ($results) = @_;
    foreach (sort keys %$results) {
	print "$_\t$$results{$_}\n";
    }
}

sub samtools {

	my ($bam, $chr, $start, $end, $out) = @_;
	my $cmd = "samtools view -bo $out $bam \'$chr:$start-$end\'";
	
	print "$cmd\n";
	
	system($cmd);
	
	$cmd = "samtools index $out";
	system($cmd);
        
}
