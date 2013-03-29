#!/usr/bin/env perl
use warnings;
use English;
use strict;

use POSIX qw(strftime :sys_wait_h);
use Time::HiRes;
use IPC::Lite Key=>"load-balance-$$", qw( %kids );
use Getopt::Long;
use Socket;

use constant OK => 0;
use constant FAIL => -1;


sub spawn(@) {
	my @hosts = @_;

	for my $host (@hosts) {
		my $pid = fork();
		$pid > 0 and next;

		alarm(1);
		bot($host);
		exit 0;
	}
}

sub mk_zone($$$$$) {
	my ($kids, $file, $zone, $host, $interval) = @_;
	local $_;

	$zone .= '.';
	my $tmp = $file . '.tmp';
	open my $fh, '>' . $tmp;
	select $fh;
	my $stamp = time();

	open my $tmpl, 'dns-zone-template.txt';
	while (<$tmpl>) {
		s/\{ZONE\}/$zone/g;
		s/\{INTERVAL\}/$interval/g;
		s/\{STAMP\}/$stamp/g;
		print;
	}
	close $tmpl;

	for (keys %$kids) {
		if ($kids->{$_}{'result'} != OK) { next; }
		print join "\t", ('','', 'IN','A', $kids->{$_}{'host'}, "\n");
	}
	select STDOUT;
	close $fh;
	rename $tmp, $file;
}

sub kids_copy($$) {
	my $kids = shift;
	my $kids_old = shift;
	local $_;

	for (keys %$kids) {
		$kids_old->{ $kids->{$_}{'host'} } = $kids->{$_}{'result'};
	}
}
sub kids_diff($$){
	my $kids = shift;
	my $kids_old = shift;
	local $_;

	if ( scalar (keys %$kids) != scalar (keys %$kids_old) ) {
		return 1;
	}

	for (keys %$kids) {
		if (! defined( $kids_old->{  $kids->{$_}{'host'} } ) ) { return 1; }
		if ($kids->{$_}{'result'} != $kids_old->{ $kids->{$_}{'host'} } ) {
			return 1;
		}
	}
	return 0;
}

sub logs($) { print STDERR POSIX::strftime('%Y%m%d %H:%M:%S ',localtime()) . $_[0] . "\n" }

sub host_to_ip($) {
	my $host = $_[0];
	chomp($host);
	my $packed_ip = gethostbyname($host);
	if (! defined $packed_ip) {
		logs "unable to resolve $host";
		return;
	}
	return inet_ntoa($packed_ip);
}


our %cfg;
our %kids = ();
our %kids_last = ();
GetOptions(\%cfg, 'interval=i', 'hosts_file=s', 'zone_file=s', 'zone=s', 'bind_cmd=s', 'bot_file=s');
if (! defined( $cfg{'bind_cmd'})) {
	$cfg{'bind_cmd'} = 'killall -HUP named';
}
if ($cfg{'bot_file'} eq '') { die "need bot_file option"; }
do $cfg{'bot_file'};

while (1) {
	my $start = Time::HiRes::time();
	%kids = ();
	my @hosts = map { host_to_ip $_ } `cat $cfg{'hosts_file'}`;
	if (scalar(@hosts) == 0) {
		logs('empty hosts file: ' . $cfg{'hosts_file'});
		exit 1;
	}
	spawn( @hosts );
	while ( (my $k = wait()) > 0) {
		if ( $kids{$k}{'result'} == FAIL ) {
			logs( 'failed host: ' . $kids{$k}{'host'} );
		}
	}

	if (kids_diff(\%kids, \%kids_last)) {
		mk_zone(\%kids, $cfg{'zone_file'}, $cfg{'zone'}, $cfg{'host'}, $cfg{'interval'});
		system( $cfg{'bind_cmd'} );
	}
	%kids_last = ();
	kids_copy(\%kids, \%kids_last);

	my $us = 1_000_000 * ( $cfg{'interval'} - (Time::HiRes::time() - $start));
	if ($us > 0) {
		Time::HiRes::usleep( $us );
	}
}
