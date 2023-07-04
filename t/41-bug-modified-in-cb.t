use strict;
use warnings;

use Test::More tests;

use AnyEvent::Filesys::Watcher;
use lib 't/lib';
use TestSupport qw(create_test_files delete_test_files move_test_files
	modify_attrs_on_test_files $dir received_events receive_event
	catch_trailing_events);

$|++;

sub run_test {
	my %extra_config = @_;

	my $n = AnyEvent::Filesys::Watcher->new(
		directories => [$dir],
		callback => sub {
			receive_event(@_);

			# This call back deletes any created files
			my $e = $_[0];
			unlink $e->path if $e->type eq 'created';
		},
		%extra_config,
	);
	isa_ok $n, 'AnyEvent::Filesys::Watcher';

	# Create a file, which will be delete in the callback
	received_events(
		sub { create_test_files('foo') },
		'foo' => 'created',
		'create a file',
	);

	# Did we get notified of the delete?
	received_events(
		sub { }, 'deleted the file',
		'foo' => 'deleted',
	);
}

run_test;

SKIP: {
	skip 'Requires Mac with IO::KQueue', 3
		unless $^O eq 'darwin' and eval { require IO::KQueue; 1; };
	run_test backend => 'KQueue';
}

catch_trailing_events;
done_testing;