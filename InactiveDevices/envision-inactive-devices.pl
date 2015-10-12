#!/usr/bin/env perl
=pod
=head1 NAME
CSV Parser and Grapher for enVision output of inactive devices

=head1 DESCRIPTION

output parsed in following csv form: "Address","Date","Count","Device"
e.g.: "1.1.1.101","2011-10-06 00:00",0,"winevent_snare"

such output can be generated using envision report CRL-00023
output should be cleaned against windows EOL, e.g using tr -d '\r\'

array used:
1. hash array %hash - entails activity and inactivity for each day and each device types.
	key for hash is comprised from {ip-type-date}
 	$hash{ip-type-date} = count
 	$hash{1.1.1.101 winevent_snare 2011-10-06} = 0
2. ips array %ips - entails all unique ip addresses in the input file
3. dates array %dates - entails all date in the input file

logic:
	csv values are being parsed. date/time is parsed for date only and is inserted into hash array %dates to have unique date.
	ip address is parsed and inserted into hash array %ips.
	activity and inactivity of each device for particular day is being counted. this is stored in hash array %hash in activity/inactivity subkeys.
	after parsing, dates array is being sorted to have output from the past till now.
	for each identified device, dns record is being found. then graph itself is generated.
	the graph uses three arrays for successful generation. each array has same length.
		first array is dates - X-label
		second array is activity count
		third array is inactivity count
	e.g.: 	dates: 2011-09-13 2011-09-14 2011-09-15 2011-09-16 2011-09-17 2011-09-18 2011-09-19 2011-09-20 2011-09-21 2011-09-22 2011-09-23 2011-09-24 2011-09-25 2011-09-26 2011-09-27 2011-09-28 2011-09-29 2011-09-30 2011-10-01 2011-10-02 2011-10-03 2011-10-04 2011-10-05 2011-10-06 2011-10-07 2011-10-08 2011-10-09 2011-10-10 2011-10-11 2011-10-12 2011-10-13 2011-10-14
	active: 0 8 5 3 2 3 6 5 1 3 2 1 1 1 3 1 1 1 0 1 1 1 1 1 1 1 1 1 3 3 1 1
	inactive: 905 1428 1435 1438 1438 1437 1435 1435 1439 1439 1437 1439 1438 1436 1436 1438 1439 1439 120 1439 1440 1439 1439 1440 1434 1439 1439 1436 1437 1434 1439 533

graph is stored in $DIR (Default /tmp/gif)
=cut

use strict;
use warnings;
use GD::Graph::bars; 

#my $file = 'out.csv';
my $file = 'CRL-00023-1318509531853.csv';
my $output = 'gif'; #default value - how the output will look like - whether CSV file or GIF files
my $BU = "Report-Prefix"; #for reports, can be SK, GR and Critical, Important so on
my %hash;
my %ips;
my %dates;
my @imgnames;
#my $DIR="/tmp/gif/";
my $DIR=".";

#start
	print STDERR "\nCSV Parser and Grapher for enVision output of inactive devices - CRL-00023-Activity\n\n";
# if defined file to parse, use it
	if ($#ARGV >= 1) {
		$file = $ARGV[0];
		$output = $ARGV[1];
		if (( "$output" ne 'csv') and ("$output" ne 'gif' )) {
			print STDERR "Wrong OUTPUT action! csv or gif permitted only\n";
			die $!;
		}
	} else {
		print STDERR "CSV Parser and Grapher for CRL-00023 report - Inactive devices\n";
		print STDERR "\tusage $0 <envision-crl-00023.csv> csv|gif\n";
		print STDERR "\n\targument is required. csv file required in form:\n";
		print STDERR "\t".'"Address","Date","Count","Device"' . "\n";
		print STDERR "\t".'"1.1.1.101","2011-10-06 00:00",0,"winevent_snare"' . "\n";
		print STDERR "\n\t".'be aware of windows end of lines (use: tr -d \'\r\')' . "\n\n";
		die $!;
	}

#create directory
	mkdir "$DIR" unless -d "$DIR";
	my $TMPDATE = `date /t`; $TMPDATE =~ s/\///g;
	my $TMPTIME = `time /t`; $TMPTIME =~ s/://g;
	chomp($TMPDATE); chomp ($TMPTIME);
	my $SUBDIR = "$TMPDATE $TMPTIME";
	
	$SUBDIR =~ s/ +/ /g; $SUBDIR =~ s/ /-/g; $SUBDIR =~ s/\.//g;
	
	
	print STDERR "script start @" . $SUBDIR ."\n";
	#subdir is created after find out how many days are in the report
	
#parse csv data
	open(FILE, "<", $file) or die $!;
	print STDERR "file $file opened\n";
	print STDERR "parsing started ...";
	while(<FILE>) {
		chomp;
		s/\"//g;
		next if /^A/;

		my @columns = split /,/;

		my $date = '0';
		$date = (split(/ /, $columns[1]))[0];
		

		#prepare key into hash array
		my $key = "$date:$columns[0]:$columns[3]";
		#default values in case of initial round
		$hash{$key}{active} = 0	if (not defined $hash{$key}{active});
		$hash{$key}{inactive} = 0 if (not defined $hash{$key}{inactive});

		#have unique dates after parsing the file
		$dates{$date} = 1;
		#have unique ips after parsing the file
		$ips{"$columns[0]:$columns[3]"} = 1;

		if ($columns[2] != 0) {
			$hash{$key}{active} += 1;
		} else {
			$hash{$key}{inactive} += 1;
		}
	}
	close FILE;

	print STDERR " done\n";
	print STDERR "file $file closed\n";

#sort dates
	my @tmpdates;
	my $date;
	#sort dates
	foreach my $key (sort keys %dates) {
		push @tmpdates, $key;
	}
	print STDERR "unique dates found\n";

#create subdir
	$SUBDIR .= "-" . ($#tmpdates + 1) . "days";

	if ($ARGV[1] eq 'gif') {
		mkdir "$DIR/$SUBDIR" unless -d "$DIR/$SUBDIR";
		print STDERR "output directory: $DIR/$SUBDIR\n";
	}

# get DNS name from IP
	sub get_dns_from_ip {

		my $realip = shift;
		print STDERR "ip: $realip\n";
		
		my $dns = "";
		if ( "$^O" eq "linux" ) {
			#get dns name
			my $dns = `dig -x $realip +time=1 +retry=1 +tries=1 +short | grep -v ';' | xargs `;
			chomp $dns;
		} else { #windows MSWin32
			my @tmpdns = `nslookup -timeout=1 $realip`; 
			my @foo = grep(/Name:/, @tmpdns);
			my @arr;
			foreach my $key (@foo) {
				my @foo2 = split(/ +/, $key);
				push @arr, $foo2[1];
			}
			foreach my $key (@arr) {
				chomp ($key);
				$dns .= "$key. ";
			}
		}
		
		if ( $dns ) {
			print STDERR "dns record: $dns\n";
			$dns = " :$dns";
		} else {
			$dns = " :nodnsrecord";
			print STDERR "dns record: unknown\n";
		}
		return $dns;
}


#output to csv
	sub output_to_csv() {
	my $half_days = (($#tmpdates + 1) / 2) + 1;
	my @arrh, my @arrl, my @arrn ; # holds parsed values
	
	foreach my $ip (sort keys %ips) {
		my $ip_activity = 0;
		
		# need to find out active/inactive devices
		#1. device was reporting more than half_days
		#2. no activity - ianctive during entire period
		#3. less than 
	
		foreach my $date (@tmpdates) {
#			print STDERR "Activity: " . $hash{"$date:$ip"}{active} . "\n";
			$ip_activity += 1 if ($hash{"$date:$ip"}{active});
#			print STDERR "$ip_activity\n";
		}
		#inactive



		my @tmpip = split (/:/, $ip);
		my $dns = "";
		$dns = get_dns_from_ip "$tmpip[0]";


		#add $dns right upon $tmpip[0] if dns is required
		if ($ip_activity < 1) {
			push @arrn, "$tmpip[1] ($tmpip[0]) : no_activity";
		} elsif ($ip_activity >= $half_days) {
			push @arrh, "$tmpip[1] ($tmpip[0]) : high_activity";
		} else {
			push @arrl, "$tmpip[1] ($tmpip[0]) : low_activity";
		}
		
	
	}
	
	my @output_file = split(/\/|\\/, $file);
	my $csv_output_file = $output_file[-1];
	$csv_output_file =~ s/\.csv$/.txt/;
	$csv_output_file = "FD-" . $BU . "-" . $csv_output_file;
	print STDERR "output file : $csv_output_file\n";
	
	
	open(CSVOUTPUTFILE, ">$csv_output_file");
	#print output
	print CSVOUTPUTFILE "-------------------------------------------------------------\n";
	print CSVOUTPUTFILE "FD $BU Activity devices REPORT\n";
	print CSVOUTPUTFILE "Days: " . ($#tmpdates + 1) . "\n";
	print CSVOUTPUTFILE "$_ " foreach (@tmpdates); print CSVOUTPUTFILE "\n";		
	print CSVOUTPUTFILE "\nStatus: \n";
	print CSVOUTPUTFILE "\tHigh_activity - active for more than a half of reporting period\n";
	print CSVOUTPUTFILE "\tLow_activity - active for less than a half of reporting period and at least 1 day active\n";
	print CSVOUTPUTFILE "\tNo_activity - inactive for entire reporting period\n";
	print CSVOUTPUTFILE "-------------------------------------------------------------\n";
	print CSVOUTPUTFILE "\n";
	print CSVOUTPUTFILE "-------------------------------------------------------------\n";
	print CSVOUTPUTFILE "List of No_activity devices logging to Envisions:\n";
	print CSVOUTPUTFILE "-------------------------------------------------------------\n";
	print CSVOUTPUTFILE"$_\n" foreach sort (@arrn);
	print CSVOUTPUTFILE "\n";
	print CSVOUTPUTFILE "-------------------------------------------------------------\n";
	print CSVOUTPUTFILE "List of Low_activity devices logging to Envisions:\n";
	print CSVOUTPUTFILE "-------------------------------------------------------------\n";
	print CSVOUTPUTFILE "$_\n" foreach sort (@arrl);
	print CSVOUTPUTFILE "\n";
	print CSVOUTPUTFILE "-------------------------------------------------------------\n";
	print CSVOUTPUTFILE "List of High_activity devices logging to Envisions:\n";
	print CSVOUTPUTFILE "-------------------------------------------------------------\n";
	print CSVOUTPUTFILE "$_\n" foreach sort (@arrh);
	print CSVOUTPUTFILE "\n";
	close (CSVOUTPUTFILE);
	
}	

#output to graph
sub output_to_gif() {
	#begin with required outputs - graphs
		print STDERR "output ready\n\n";
		foreach my $ip (sort keys %ips) {
			my @dataset_active;
			my @dataset_inactive;
		
			foreach my $date (@tmpdates) {
				if ( ! $hash{"$date:$ip"}{active}) {
					push @dataset_active, 0;
					push @dataset_inactive, 1440;		
				} else {
					if ( $hash{"$date:$ip"}{active} < 10) {
						push @dataset_active, $hash{"$date:$ip"}{active} * 30;
						push @dataset_inactive, 0;
					} else {
						push @dataset_active, $hash{"$date:$ip"}{active};
						push @dataset_inactive, 0;
					}
				}

			}
		

			#get realip for dns record searching
			my $realip = (split(/:/,$ip))[0];
			print STDERR "ip: $realip\n";
			
			my $dns = "";
			$dns = get_dns_from_ip "$realip";
							
			#print graph
			print STDERR "device: $ip\n";
			print STDERR "dates: @tmpdates\n";
			print STDERR "active: @dataset_active\n";
			print STDERR "inactive: @dataset_inactive\n";
		
			my @data = ([@tmpdates],[@dataset_inactive],[@dataset_active],);	
			
			my $my_graph = GD::Graph::bars->new(800, 600);
			my $name = "activityreport-device-$ip.gif";
			print STDERR "processing $name\n"; 
			
			my $y_max_value = 60 * 24 + 100;
			$my_graph->set( 
				x_label => 'Date', 
				x_labels_vertical => 1,
				y_label => 'Count',
				title => "CRL-00023 $ip $dns",
				#y_tick_number => 8, 
				#y_label_skip => 2, 
				overwrite => 1, 
				bar_spacing => 8, 
				shadow_depth => 0, 
				y_label_skip => 2, 
				y_max_value => $y_max_value, 
			); 
			
			$my_graph->set_legend('Inactivity', 'Activity'); 
			my $gd = $my_graph->plot(\@data); 
			$name =~ s/:/-/g;
			print STDERR "file name: $DIR/$SUBDIR/$name\n";
			open(IMG, ">$DIR/$SUBDIR/$name") or die $!;
			binmode IMG;
			print IMG $gd->gif;
			close IMG;
			print "done!\n\n";
		
		}
		print STDERR "finished successfully\n";

		$SUBDIR = `date /t && time /t`;
		print STDERR "script end @" . $SUBDIR . "\n\n";
}

#generate output
if ($output eq 'csv') {
	print STDERR "output: CSV\n";
	output_to_csv();
} else {
	print STDERR "output: GIF\n";
	output_to_gif();
}