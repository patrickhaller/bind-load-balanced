caller() ? 1 : die 'not standalone, use from load.pl';

sub bot($) {
	my $host = shift;
	$kids{ $PID }{'host'} = $host;

	use IO::Socket::INET; 
	$sock = IO::Socket::INET->new("${host}:25");
	$banner = <$sock>; 
	close $sock;
	$banner =~ /^220/ and do { 
		$kids{ $PID }{'result'} = OK;
		exit OK;
	};
	$kids{ $PID }{'result'} = FAIL;
	exit FAIL;
}

