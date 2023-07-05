use strict;
use warnings;

use Test::More;

use AnyEvent::Filesys::Watcher;
use lib 't/lib';
use TestSupport qw(create_test_files delete_test_files move_test_files
	modify_attrs_on_test_files $dir received_events receive_event
	catch_trailing_events next_testing_done_file);

$|++;

# Prevent the directory 'one' from being created by the TestSupport library.
$TestSupport::testing_done_format = 'testing-done-%u';

sub run_test {
	my %extra_config = @_;

	my $n = AnyEvent::Filesys::Watcher->new(
		directories => [$dir],
		callback => sub {
			receive_event(@_);

			# This call back deletes any created files
			foreach my $event (@_) {
				if ($event->path !~ m{/testing-done-[1-9][0-9]*$}) {
					unlink $event->path if $event->type eq 'created'
						&& !$event->isDirectory;
				}
			}
		},
		%extra_config,
	);
	isa_ok $n, 'AnyEvent::Filesys::Watcher';

	# Create a file, which will be delete in the callback
	received_events(
		sub { create_test_files('foo') },
		'create a file',
		foo => 'created',
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
