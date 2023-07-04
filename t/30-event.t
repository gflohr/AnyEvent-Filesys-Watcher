use strict;
use warnings;

use Test::More;

BEGIN {
	my $module;
	if ($^O eq 'linux') {
		$module = 'Linux/Inotify2.pm';
	} elsif ($^O eq 'darwin') {
		$module = 'Mac/FSEvents.pm';
	} elsif ($^O eq 'MSWin32' || $^O eq 'cygwin') {
		$module = 'Filesys/Notify/Win32/ReadDirectoryChanges.pm';
	} elsif ($^O =~ /bsd/i) {
		$module = 'IO/KQueue.pm';
	}

	if ($module) {
		eval { require $module };
		plan(skip_all => "no os-specific backend installed") if $@;
	}
}

use File::Spec;

use lib 't/lib';
$|++;
use AnyEvent::Filesys::Watcher;
use TestSupport qw(create_test_files delete_test_files move_test_files
	modify_attrs_on_test_files $dir received_events receive_event
	catch_trailing_events);

create_test_files qw(one/1);
create_test_files qw(two/1);
create_test_files qw(one/sub/1);
## ls: one/1 one/sub/1 two/1

my $n = AnyEvent::Filesys::Watcher->new(
	directories => [ map { File::Spec->catfile($dir, $_ ) } qw(one two) ],
	filter => sub { shift !~ qr{/ignoreme$} },
	callback => sub { receive_event(@_) },
);
isa_ok $n, 'AnyEvent::Filesys::Watcher';

SKIP: {
	skip "not sure which os we are on", 1
		unless $^O =~ /linux|darwin|bsd|MSWin32|cygwin/i;
	isa_ok($n, 'AnyEvent::Filesys::Watcher::Inotify2',
		'... with the linux backend')
		if $^O eq 'linux';
	isa_ok($n, 'AnyEvent::Filesys::Watcher::FSEvents',
		'... with the mac backend')
		if $^O eq 'darwin';
	isa_ok($n, 'AnyEvent::Filesys::Watcher::ReadDirectoryChanges',
		'... with the MS-DOS backend')
		if $^O eq 'MSWin32';
	isa_ok($n, 'AnyEvent::Filesys::Watcher::ReadDirectoryChanges',
		'... with the MS-DOS backend')
		if $^O eq 'cygwin';
	isa_ok($n, 'AnyEvent::Filesys::Watcher::KQueue',
		'... with the bsd backend')
		if $^O =~ /bsd/;
}

diag "This might take a few seconds to run...";

# ls: one/1 one/sub/1 +one/sub/2 two/1
received_events(
	sub { create_test_files(qw(one/sub/2)) },
	'create a filex',
	'one/sub/2', 'created',
);

# ls: one/1 +one/2 one/sub/1 one/sub/2 two/1 +two/sub/2
received_events(
	sub { create_test_files(qw(one/2 two/sub/2)) },
	'create file in new subdir',
	'one/2' => 'created',
	'two/sub' => 'created',
	'two/sub/2' => 'created',
);

# ls: one/1 ~one/2 one/sub/1 one/sub/2 two/1 two/sub/2
received_events(
	sub { create_test_files(qw(one/2)) },
	'modify existing file',
	'one/2' => 'modified',
);

# ls: one/1 one/2 one/sub/1 one/sub/2 two/1 two/sub -two/sub/2
received_events(
	sub { delete_test_files(qw(two/sub/2)) },
	'deletes a file',
	'two/sub/2' => 'deleted',
);

# ls: one/1 one/2 +one/ignoreme +one/3 one/sub/1 one/sub/2 two/1 two/sub
received_events(
	sub { create_test_files(qw(one/ignoreme one/3)) },
	'creates two files one should be ignored',
	'one/3' => 'created'
);

# ls: one/1 one/2 one/ignoreme -one/3 +one/5 one/sub/1 one/sub/2 two/1 two/sub
received_events(sub { move_test_files('one/3' => 'one/5' ) },
	'move files',
	'one/3' => 'deleted',
	'one/5' => 'created',
);

SKIP: {
	skip "skip attr mods on Win32", 1 if ($^O eq 'MSWin32' || $^O eq 'cygwin');

	# ls: one/1 one/2 one/ignoreme one/5 one/sub/1 one/sub/2 ~two/1 ~two/sub
	received_events(
		sub { modify_attrs_on_test_files(qw(two/1 two/sub)) },
		'modify attributes',
		'two/1' => 'modified',
		'two/sub' => 'modified',
	);
}

# ls: one/1 one/2 one/ignoreme +one/onlyme +one/4 one/5 one/sub/1 one/sub/2 two/1 two/sub
$n->filter(qr/onlyme/);
received_events(sub { create_test_files(qw(one/onlyme one/4)) },
	'filter test',
	'one/onlyme' => 'created',
);

catch_trailing_events;
done_testing;
