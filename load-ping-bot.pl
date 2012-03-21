caller() ? 1 : die 'not standalone, use from load.pl';

sub bot($) {
	my $host = shift;
	$kids{ $PID }{'host'} = $host;
	my $pid = open my $fh, "ping -W 3 -c 1 $host  2>&1 |";
	$SIG{'ALRM'} = sub {
		kill 9, $pid;
		$kids{ $PID }{'result'} = FAIL;
		exit FAIL;
	};
	my @lines = <$fh>;
	close $fh;
	$kids{ $PID }{'result'} = OK;
	exit OK;
}

