use strict;
use warnings;

use Test::More;
use File::Spec;
use lib 't/lib';
$|++;

use TestSupport qw(create_test_files delete_test_files move_test_files
	modify_attrs_on_test_files $dir received_events receive_event
	catch_trailing_events next_testing_done_file EXISTS DELETED);

use AnyEvent::Filesys::Watcher;

unless ($^O eq 'darwin' and eval { require IO::KQueue; 1; }) {
	plan skip_all => 'Test only on Mac with IO::KQueue';
}

create_test_files qw(one/1);
create_test_files qw(two/1);
create_test_files qw(one/sub/1);
## ls: one/1 one/sub/1 two/1

my $n = AnyEvent::Filesys::Watcher->new(
	directories => [ map { File::Spec->catfile($dir, $_) } qw(one two) ],
	filter => sub { shift->path !~ qr{/ignoreme$} },
	callback => sub { receive_event(@_) },
	backend => 'KQueue',
);
isa_ok $n, 'AnyEvent::Filesys::Watcher';
isa_ok $n, 'AnyEvent::Filesys::Watcher::KQueue',
	'... with the KQueue backend';

diag "This might take a few seconds to run...";

# ls: one/1 one/sub/1 +one/sub/2 two/1
received_events(sub { create_test_files(qw(one/sub/2)) },
	'create a file',
	'one/sub/2' => EXISTS,
);

# ls: one/1 +one/2 one/sub/1 one/sub/2 two/1 +two/sub/2
received_events(
	sub { create_test_files(qw(one/2 two/sub/2)) },
	'create file in new subdir',
	'one/2' => EXISTS,
	'two/sub' => EXISTS,
	'two/sub/2' => EXISTS,
);

# ls: one/1 ~one/2 one/sub/1 one/sub/2 two/1 two/sub/2
received_events(
	sub { create_test_files(qw(one/2)) },
	'modify existing file',
	'one/2' => EXISTS,
);

# ls: one/1 one/2 one/sub/1 one/sub/2 two/1 two/sub -two/sub/2
received_events(
	sub { delete_test_files(qw(two/sub/2)) },
	'deletes a file',
	'two/sub/2' =>  DELETED
);

# ls: one/1 one/2 +one/ignoreme +one/3 one/sub/1 one/sub/2 two/1 two/sub
received_events(
	sub { create_test_files(qw(one/ignoreme one/3)) },
	'creates two files one should be ignored',
	'one/3' => EXISTS,
);

# ls: one/1 one/2 one/ignoreme -one/3 +one/5 one/sub/1 one/sub/2 two/1 two/sub
received_events(sub { move_test_files('one/3' => 'one/5') },
	'move files',
	'one/3' => DELETED,
	'one/5' => EXISTS,
);

SKIP: {
	skip "skip attr mods on Win32", 1 if $^O eq 'MSWin32';

	# ls: one/1 one/2 one/ignoreme one/5 one/sub/1 one/sub/2 ~two/1 ~two/sub
	received_events(
		sub { modify_attrs_on_test_files(qw(two/1 two/sub)) },
		'modify attributes',
		'two/1' => EXISTS,
		'two/sub' => EXISTS,
	);
}

# ls: one/1 one/2 one/ignoreme +one/onlyme +one/4 one/5 one/sub/1 one/sub/2 two/1 two/sub
my $trigger_filename = next_testing_done_file;
$n->filter(qr{/(?:onlyme|$trigger_filename)$});
received_events(
	sub { create_test_files(qw(one/onlyme one/4)) },
	'filter test',
	'one/onlyme' => EXISTS,
);

catch_trailing_events;
done_testing;
