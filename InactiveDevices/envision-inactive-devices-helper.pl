#!/usr/bin/env perl
# Helper's goal is to find relevant reports for CRL-00023 on envision and run the envision-inactive-devices.pl.
# Then it compress the outputs and sent to relevant parties that are going to review the report.


use strict;
use warnings;
use File::Find;

my $DIR = 'E:\reporting';
my $MAILER = 'E:\reporting\envision-inactive-devices-mailer.vbs';
my $LOGFILE = 'E:\reporting\envision-inactive-devices-log.log';
my $MAINSCRIPT = 'E:\reporting\envision-inactive-devices.pl';
my $ENVISIONDIR = 'E:\nic\4100\ENVISION-ES\webapps\pi\pireport';
my $STATFILE = 'E:\reporting\envision-inactive-devices-helper-statfile.log';
my @reports; #reports from envision pireport directory
my @processed_reports; #reports already processed
my @to_generate; #to be generated reports


chdir "$DIR";

open(LOG, ">>$LOGFILE");
print LOG `date /t`;
print LOG `time /t`;

#initialize and read status file; what names of reports have been already processed
sub create_file {
	open(FH,">$STATFILE"); 
	close(FH);	
}
print LOG "Reading stat file\n";


open(FILE, "$STATFILE") or create_file(); 
while (<FILE>) {
	chomp;
	s/ +//g;
	push @processed_reports, $_;
}
close (FILE);

#find generated reports stored in envision dir
print LOG "Searching for generated reports in $ENVISIONDIR\n";
find( sub {push @reports, "$File::Find::name" if (/^CRL-00023.*csv/)},"$ENVISIONDIR");

#compare which ones are not processed, and then generate the reports
foreach my $i (@reports) {
	if ( -s $i <=0 ) { #do not process reports that are empty
		print LOG "Zero length, not processing: $i\n";
		next;
	}


	my @filename =(split/(\\|\/)/, "$i"); #file is on last position
	my $is_generated = 0;
	foreach my $j (@processed_reports) {
		$is_generated = $is_generated || ("$filename[-1]" eq "$j");
#		print "Status: $is_generated\n";
	}
	print "New CSV for reporting $i\n" if ! $is_generated;
	push @to_generate, "$i" if ! $is_generated;
}

if ($#to_generate < 0) {
	print LOG "No new csv for reporting! Exit.\n";
	print LOG "\n";
	close (LOG);
	exit;
}

print "Running report generation\n";
#generate files
foreach my $csvfile(@to_generate) {
	#print "system($MAINSCRIPT, \"$csvfile\");\n";

	#graphs
	system("perl", $MAINSCRIPT, "$csvfile", "gif");
	#csv file
	system("perl", $MAINSCRIPT, "$csvfile", "csv");

	my @filename =(split/(\\|\/)/, "$csvfile"); #file is on last position
	#rembember processed files in statfile
	`echo $filename[-1] >> "$STATFILE"`;
}


#sent and compress graph reports
my @dirs;
find( sub {push @dirs, "$File::Find::name" if (/days$/)},".");

#compare which ones are not processed, and then generate the reports
print "Preparing zip files for graphs\n";
foreach my $i (@dirs) {
	$i =~ s/\.\///g;
	#compress
	print LOG "Compressing $i.zip\n";
	system("zip","-r","$i.zip","$i");
	#clean
	print LOG "Deleting \n";
	system("del","/Q","$i");
	rmdir "$i";
}

#sent files csv and gif
@dirs = ();
find( sub {push @dirs, "$File::Find::name" if (/zip$|.*CRL-00023.*txt$/)},".");

#compare which ones are not processed, and then generate the reports
print "\nCompressing and sending emails\n";
foreach my $i (@dirs) {
	$i =~ s/\.\///g;
	print "SEND COMPRESS\n";
	print "$i\n";


	#compress
	print LOG "sending $MAILER" . "\"$DIR\\" . "$i\"\n";
	system("cscript", "$MAILER", "\"$DIR\\" . "$i\"");

	#clean
	print LOG "Deleting $i\n";
	unlink "$i";

}


print LOG "Done\n";
print LOG "\n";
close(LOG);