#!/usr/bin/perl


# Syslog Generator


# Purpose: It is the generator of syslog messages from the file while spoofing source address to simulate syslog traffic from original host
# Required Inputs: UNX file from RSA enVision system exported by lsdata command: lsdata -d 0 -devices * -time -365d now

# 	Structure of UNX FILE
#		<Month> <Date> <HH:MM:SS> [<Source IP Address] <Raw syslog message>
# 	Sample UNX file:
# 		Sep 15 00:04:43 [10.20.30.40] Sep 15 00:04:43 Message forwarded from server: su: from root to console at /dev/tty??

# How it works: The script parses out the source IP address and raw syslog message. It optionaly randomizes all IP addresses while keeping 1:1 mapping. Same IP addresses will be assigned always to same randomized IP address. The script then randomly chooses facility and severity levels for syslog message. The syslog message is constructed and send randomly to syslog hosts.

# todo: randomize dst udp port for syslog
# todo: check for input


#############################################################
#variables
############################################################

#define all syslogs hosts e.g. forwarders that will receive syslog messages and will be choosed randomly during syslog message generation
my @syslog_hosts = qw/1.2.3.4 5.6.7.8/;	
my $DoYouWantToAnonymize = 1;

my $sendSyslog = 1;		# controls if the syslog is actually sent
my $verbose = 1;		# verbose output
my $storeMapping = 1;		# controls whether IP mapping is stored in file.
my $isNotFirstAttempt = 0;	# used for recursive msg parsing, do not change!
my $anonymizeSource = 1;	# controls whether IP address of the device is being anonymized
my $anonFile = 'hasharr.cfg';	# used to store 1:1 ip address mapping
my %anonIParr;			# used for 1:1 mapping for anonymizing purposes of IP addresses
my $counter;			# used for statistical purposes
my $time;			# used for statistical purposes

use strict; 
use warnings;
use lib './';
use Packet::UDP::Syslog;
use POSIX qw/strftime/;
 

#used as constants, dont change it!
my @syslog_severities = qw/info err emerg alert debug crit warn notice debug/;
my @syslog_facilities = qw/kernel user mail system security internal print news uucp clock security2 ftp ntp logaudit logalert clock2 local0 local1 local2 local3 local4 local5 local6 local7/;

 
############################################################
#code
############################################################

#Desc: Read IP address mapping from $anonFile variable
sub _readAnonArray {
	if ( -e $anonFile) {
		open (HASARR, "<$anonFile");
		while (<HASARR>) {
			chomp;
			my @arr = split / /;
			$anonIParr{$arr[0]} = $arr[1];
		}
		close(HASARR);
	}
}

#Desc: Write IP Address mapping to file $anonFile
sub _writeAnonArray {
	open (HASHARR, ">$anonFile");
	foreach my $key (keys %anonIParr) {
		print HASHARR "$key $anonIParr{$key}\n";
	}
	close(HASHARR);
}

#Desc: This procedure is used to anonymize IP addresses in the message
sub _anonymizeIPAddress {
	sub _randIP {
		my $tmpIP = 1 + int(rand(200));
		$tmpIP .= "." . (1 + int(rand(200)));
		$tmpIP .= "." . (1 + int(rand(200)));
		$tmpIP .= "." . (1 + int(rand(200)));
		return $tmpIP;
	}

	my $ipaddress = shift;
	my $my_anonymized_IP;

	#fallback rule if we dont want to anonymize the IP addresses	
	if (not $DoYouWantToAnonymize) {
		return $ipaddress;
	}

	if (not $anonIParr{$ipaddress}) {
		$my_anonymized_IP = _randIP();
		$anonIParr{$ipaddress} = $my_anonymized_IP;
	} else {
		$my_anonymized_IP = $anonIParr{$ipaddress};
	}
	print " Syslog Generator: $counter: IP Address Anonymizer: $ipaddress -> $my_anonymized_IP\n" if ($verbose);
	return $my_anonymized_IP;

}

#Desc: This procedure is used to recursively find IP addresses in the message, provide them to _anonymizeIPaddress and construct new message with replaced IP addresses
sub _anonymizeMsg {
	my $my_msg = shift;
	my $output_msg; my $last_match;
	if ($my_msg =~ m/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/g) {
		$isNotFirstAttempt = $isNotFirstAttempt or 1;
		$output_msg .= $`;
		$output_msg .= _anonymizeIPAddress($&);
		#$output_msg .= "1.2.3.4";
		$output_msg .= _anonymizeMsg($');
	} else {
		if ( not $isNotFirstAttempt ) {
			$output_msg = $my_msg;
		} else { 
			$output_msg .= $';
		}
	}

	return $output_msg;
}

#Desc: Choose syslog collector randomly. Can be extended in future for more sophisticated algorithm.
sub _randCollector {
	my $randIndex = int(rand($#syslog_hosts + 1));
	return $randIndex;
}

#Desc: This procedure is used to send syslog message to syslog collector
sub _sentSyslog {
	my $my_src = shift;
	my $my_msg = shift;

	my $my_collector = _randCollector;
	print " Syslog Generator: $counter: Syslog: Following syslog collector selected: $syslog_hosts[$my_collector]\n";
	if ($sendSyslog) { 
		my $syslog = Packet::UDP::Syslog->new($my_src, $syslog_hosts[$my_collector]);

		#choose random facility and severity level for syslog message
		$syslog->pkt_payload($syslog_facilities[int(rand($#syslog_facilities + 1))], $syslog_severities[int(rand($#syslog_severities + 1))], "$my_msg");
	#	$syslog->pkt_send(0,1);
		print " Syslog Generator: $counter: Syslog: Send ... success\n";
	}
}

#Desc: Print just info about settings and wait 3 sec.
sub _info {
	print "\n Syslog Generator: \$storeMapping: $storeMapping\n";
	print " Syslog Generator: \$sendSyslog: $sendSyslog\n";
	print " Syslog Generator: \$anonymizeSource: $anonymizeSource\n";
	print " Syslog Generator: \$verbose: $verbose\n";
	print " Syslog Generator: \$DoYouWantToAnonymize: $DoYouWantToAnonymize\n";
	print " Syslog Generator: \@syslog_hosts:"; print " $_" foreach (@syslog_hosts); print "\n";
	print " Syslog Generator: \$udp_port: 514\n";

	print "\n\tsleeping for 5 seconds ...\n";
	sleep 5;
}

########################################################
#main
#######################################################

#check arguments
if ($#ARGV < 0) {
	print " Syslog Generator: missing argument! Missing UNX file!\n";
	print "\tusage: perl $0 <unxfile.unx>\n";
	die;
}
if (! -e $ARGV[0]) {
	print " Syslog Generator: file does not exists!\n";
	die;
}
#initialize the hash array holding
_readAnonArray if ($storeMapping);

#print info
_info;

#statistical purposes
$time = time;
$counter = 0;

#we rely on proper UNX file from RSA enVision system - see description on the top
open (UNXFILE, "$ARGV[0]") || die ' Syslog Generator: Cannot open input UNX file!';
while(<UNXFILE>) {

	++$counter;

	chomp;
	my $msg = $_;
	my @msg_parsed = split (/ /, $msg );

	#prepare source IP address
	my $parsed_source_address = $msg_parsed[3];
	$parsed_source_address  =~ s/[\[\]]//g;
	print " Syslog Generator: $counter: Parsed source address: $parsed_source_address\n" if ($verbose);

	#prepare raw message
	my $parsed_source_message; my $i;
	for ( $i=4; $i<= $#msg_parsed; ++$i ) {
		$parsed_source_message .= $msg_parsed[$i] . " ";
	}
	$parsed_source_message =~ s/ $//g;
	print " Syslog Generator: $counter: Parsed message: $parsed_source_message\n" if ($verbose);
	
	#anonymize source address of device for IP spoofing
	my $anonymized_src;
	if ($anonymizeSource) {
		$anonymized_src = _anonymizeIPAddress ($parsed_source_address);
	} else {
		$anonymized_src = $parsed_source_address;
	}

	#anonymize all IP addresses inside message
	$isNotFirstAttempt = 0; #required for recursion fallback
	my $anonymized_msg =_anonymizeMsg ($parsed_source_message);

	#print info messages
	print " Syslog Generator: $counter: Output spoofed address: $anonymized_src\n" if ($verbose);
	print " Syslog Generator: $counter: Output message: $anonymized_msg\n";

	#send syslog
	_sentSyslog ($anonymized_src, $anonymized_msg) if ($sendSyslog);
	print "\n";
}

close(UNXFILE);

$time = time - $time;
_writeAnonArray if ($storeMapping);


print "\n\n Syslog Generator: Total Time: $time seconds\n";
print " Syslog Generator: Line proceeded/Syslog sent: $counter\n";
print "\t\n\n";



0;
