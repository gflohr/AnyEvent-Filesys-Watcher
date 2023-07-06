use strict;
use warnings;

use File::Spec;
use Test::More;

use AnyEvent::Filesys::Watcher;
use lib 't/lib';
use TestSupport qw(create_test_files delete_test_files move_test_files
	modify_attrs_on_test_files $dir received_events receive_event
	catch_trailing_events EXISTS DELETED);

$|++;

my $no_backend;

BEGIN {
	my $module;
	if ($^O eq 'linux') {
		$module = 'Linux/Inotify2.pm';
	} elsif ($^O eq 'darwin') {
		$module = 'Mac::FSEvents';
	} elsif ($^O eq 'MSWin32' || $^O eq 'cygwin') {
		$module = 'Mac::FSEvents';
	} elsif ($^O =~ /bsd/i) {
		$module = 'IO::KQueue';
	}

	if ($module) {
		eval { require $module };
		$no_backend = $@;
	}
}

create_test_files qw(one/1 two/1 one/sub/1);

my $n = AnyEvent::Filesys::Watcher->new(
	directories => [ map { File::Spec->catfile($dir, $_)} qw(one two) ],
	callback => sub { receive_event(@_) },
	skip_subdirectories => 1,
);
isa_ok $n, 'AnyEvent::Filesys::Watcher';

SKIP: {
	skip "not sure which os we are on", 1
		unless $^O =~ /linux|darwin|bsd/;
	skip "no os-specific backend installed" if $no_backend;

	isa_ok($n, 'AnyEvent::Filesys::Watcher::Inotify2',
		'... with the linux backend')
		if $^O eq 'linux';
	isa_ok($n, 'AnyEvent::Filesys::Watcher::FSEvents',
		'... with the mac backend')
		if $^O eq 'darwin';
	isa_ok($n, 'AnyEvent::Filesys::Watcher::KQueue',
		'... with the bsd backend')
		if $^O =~ /bsd/;
}

diag "This might take a few seconds to run...";

# ls: one/1 +one/2 one/sub/1 two/1
received_events(sub { create_test_files(qw(one/2)) },
	'create a file',
	'one/2' => EXISTS,
);

# ls: one/1 ~one/2 one/sub/1 two/1
received_events(sub { create_test_files(qw(one/2)) },
	'modify a file',
	'one/2' => EXISTS,
);

# ls: one/1 -one/2 one/sub/1 two/1
received_events(sub { delete_test_files(qw(one/2)) },
	'delete a file',
	'one/2' => DELETED,
);

# ls: one/1 +one/2 one/sub/1 +one/sub/2 two/1
received_events(sub { create_test_files(qw(one/sub/2 one/2)) },
	'create a file in subdir',
	'one/2' => EXISTS,
);

# ls: one/1 ~one/2 one/sub/1 ~one/sub/2 two/1
received_events(sub { create_test_files(qw(one/sub/2 one/2)) },
	'modify a file in subdir',
	'one/2' => EXISTS,
);

# ls: one/1 -one/2 one/sub/1 -one/sub/2 two/1
received_events(sub { delete_test_files(qw(one/sub/2 one/2)) },
	'delete a file in subdir',
	'one/2' => DELETED,
);

SKIP: {
	skip "skip attr mods on Win32", 1 if $^O eq 'MSWin32';

	# ls: one/1 one/sub/1 ~two/1
	received_events(sub { modify_attrs_on_test_files(qw(two/1)) },
		'modify attributes',
		'two/1' => EXISTS,
	);

	# ls: one/1 +one/2 ~one/sub/1 two/1
	received_events(sub {
		modify_attrs_on_test_files(qw(one/sub/1));
		create_test_files(qw(one/2));
		},
		'modify attributes in a subdir',
		'one/2' => EXISTS,
	);
}

# Make sure that the destructor of Filesys::Notify::Win32::ReadDirectoryChanges
# is called first so that all watching threads are joined.  Otherwise
# spurious warnings like "The handle is invalid at ..." may occur or
# "cannot remove directory for C:\...: Permission denied".
undef $n;

catch_trailing_events;
done_testing;
