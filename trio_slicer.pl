#!/usr/bin/perl

use strict;
use warnings;
use IO::Socket::INET;
use File::Basename;
use Getopt::Long;

my %args;
GetOptions(\%args,
		   "irods",
		   "bams=s",
		   "hostname=s",
		   "port=i",
		   "window=i",
		   "slicedir=s",
		   "volumes=s",
		   "output=s"
	);

my ($bamFile, $hostname, $port, $window, $slicedir, $volumes, $output, $is_stdout, $irods) = setOptions(\%args);

open (BAM, "<$bamFile") || die "Cannot open file: $!";

my $socket = new IO::Socket::INET (PeerHost => $hostname,
								   PeerPort => $port,
								   Proto => 'tcp'
	) || die "ERROR in Socket Creation or cannot connect to IGV: $!";

print "Socket connection successful.\n";

my %results;

print "Iterating through files/coordinates in -bams, type QUIT to exit and print all information!\n\n";

my @header;
my $foundheader = 'false';

foreach my $site (<BAM>) {
	
	chomp $site;

	if ($site =~ /^#/) {
		@header = split("\t", $site);
		$foundheader = 'true';
	} else {
	
		my @data = split("\t", $site);
	
		my $chr = $data[3];
		my $pos = $data[4];
		my $left = $data[4] - $window;
		my $right = $data[4] + $window;
		
		my $dir = $slicedir;
		my $loadDir = $volumes;

		my $proband = $data[0];
		my ($pName, $a, $b) = fileparse($proband, qr/\.[^.]*/);
		my $mum = $data[1];
		my $dad = $data[2];

		print $socket "new\n";
		print $socket "setSleepInterval 100\n";
		samtools($proband, $chr, $left, $right, $slicedir . "proband.$pName.$chr" . "_$pos.bam");
		print $socket "load $volumes" . "proband.$pName.$chr" . "_$pos.bam\n";
		
		if ($mum ne "-") {
			my ($mName, $c, $d) = fileparse($mum, qr/\.[^.]*/);
			samtools($mum, $chr, $left, $right, $slicedir . "mum.$mName.$chr" . "_$pos.bam");
			print $socket "load $volumes" . "mum.$mName.$chr" . "_$pos.bam\n";
		}
		if ($dad ne "-") {
			my ($dName, $c, $d) = fileparse($dad, qr/\.[^.]*/);
			samtools($dad, $chr, $left, $right, $slicedir . "dad.$dName.$chr" . "_$pos.bam");
			print $socket "load $volumes" . "dad.$dName.$chr" . "_$pos.bam\n";
		}

		print $socket "squish\n";
	
		print "Pos : $chr:$pos\n";
		print "Prob: $proband\n";
		print "P1  : $mum\n";
		print "P2  : $dad\n";

		## Print additional columns:
		for (my $x = 5; $x < scalar(@data); $x++) {
			if ($foundheader eq 'true' && scalar(@header) == scalar(@data)) {
				print "$header[$x]: $data[$x]\n";
			} else {
				my $datNum = $x - 4;
				print "Dat$datNum: $data[$x]\n";
			}
		}
		
		print $socket "goto $chr:$left-$right\n";

		print "Site Quality <enter value and hit return>: ";
		my $wait = <STDIN>;
		chomp $wait;
	
		if ($wait eq 'QUIT') {

			if ($is_stdout eq 'TRUE') {

				dumpResults(\%results, $output);
				die "IGVEugene exited via user command, dumping to STDOUT";

			} else {
				
				die "IGVEugene exited via user command";

			}

		}
		
		if ($is_stdout eq 'TRUE') {

			$results{$chr . "\t" . $pos . "\t" . $pName} = $wait;

		} else {

			print $output $chr . "\t" . $pos . "\t" . $pName . "\t" . $wait . "\n";

		}

		
	}
}

dumpResults(\%results, $output);

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

	my $volumes;
	if ($$opt{volumes}) {
		$volumes = $$opt{volumes};
	} else {
		die "Need directory for -volumes!";
	}
	

	my $port;
	if ($$opt{port}) {
		$port = $$opt{port};
	} else {
		print "No value for -port provided, setting to default IGV port of 60151\n\n";
		$port = 60151;
	}

	my $window;
	if ($$opt{window}) {
		$window = $$opt{window};
	} else {
		$window = 50;
	}

	my $output;
	my $is_stdout = 'TRUE';

	if ($$opt{output}) {
		if (-e $$opt{output}) {
			die "Will not clobber file $$opt{output}... Please enter a new file name or move the old file...\n";
		}
		$is_stdout = 'FALSE';
		open($output, ">$$opt{output}") || die "cannot make output: $!";
	} else {
		$output = *STDOUT;
	}

	my $irods;
	if ($$opt{irods}) {
		$irods = 'true';
	} else {
		$irods = 'false'
	}
	
	return($bamFile, $hostname, $port, $window, $slicedir, $volumes, $output, $is_stdout, $irods);

}
	
sub dumpResults {

    my ($results, $outputfh) = @_;
    foreach (sort keys %$results) {
		print $outputfh "$_\t$$results{$_}\n";
    }
}

sub samtools {

	my ($bam, $chr, $start, $end, $out) = @_;

	my $cmd;
	if ($irods eq 'true') {
		$cmd = "samtools view -bo $out irods:$bam \'$chr:$start-$end\'";
	} else {
		$cmd = "samtools view -bo $out $bam \'$chr:$start-$end\'";
	}
	
	system($cmd);
		
	$cmd = "samtools index $out";
	system($cmd);
        
}
