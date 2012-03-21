caller() ? 1 : die 'not standalone, use from load.pl';

sub bot($) {
	my $host = shift;
	$kids{ $PID }{'host'} = $host;
	my $pid = open my $fh, "ldapsearch -b dc=ofs,dc=edu,dc=sg -x -h $host '(mail=root*)' 2>&1 |";
	$SIG{'ALRM'} = sub {
		kill 9, $pid;
		$kids{ $PID }{'result'} = FAIL;
		exit FAIL;
	};
	my @lines = grep { /root/ } <$fh>;
	close $fh;

	if (scalar(@lines) > 0) {
		$kids{ $PID }{'result'} = OK;
		exit OK;
	}

	$kids{ $PID }{'result'} = FAIL;
	exit FAIL;
}
