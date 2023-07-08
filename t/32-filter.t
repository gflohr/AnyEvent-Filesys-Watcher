use strict;
use warnings;

use Test::More;
use File::Spec;

use lib 't/lib';
use TestSupport qw(create_test_files delete_test_files move_test_files
	modify_attrs_on_test_files test EXISTS DELETED);

$|++;

# ls: +foo +bar +baz
test(
	setup => sub { create_test_files(qw(foo bar baz)) },
	description => 'create three files',
	expected => {
		foo => EXISTS,
		bar => EXISTS,
		baz => EXISTS,
	},
	backend => 'Fallback',
);

# ls: ~foo bar ~baz
test(
	setup => sub { create_test_files(qw(foo baz)) },
	description => 'modify two files',
	expected => {
		foo => EXISTS,
		baz => EXISTS,
	},
	backend => 'Fallback',
);

# ls: foo bar baz +subdir/file
test(
	setup => sub { create_test_files(qw(subdir/file)) },
	description => 'create file in subdirectory',
	expected => {
		subdir => EXISTS,
		'subdir/file' => EXISTS,
	},
	backend => 'Fallback',
);

SKIP: {
	skip "skip attr mods on Win32", 1 if $^O eq 'MSWin32';

	# ls: ~foo ~bar baz subdir/file
	test(
		setup => sub { modify_attrs_on_test_files(qw(foo bar)) },
		description => 'modify attributes',
		expected => {
			'foo' => EXISTS,
			'bar' => EXISTS,
		},
		backend => 'Fallback',
	);
}

# ls: foo bar -baz +bazoo subdir/file
test(
	setup => sub { move_test_files(qw(baz bazoo)) },
	description => 'move file',
	expected => {
		baz => DELETED,
		bazoo => EXISTS,
	},
	backend => 'Fallback',
);

# ls: foo bar -bazoo subdir/file
test(
	setup => sub { move_test_files(qw(bazoo bar)) },
	description => 'move and overwrite file',
	expected => {
		bazoo => DELETED,
		bar => EXISTS,
	},
	backend => 'Fallback',
);

# ls:
test(
	setup => sub { delete_test_files(qw(foo bar subdir/file subdir)) },
	description => 'move and overwrite file',
	expected => {
		foo => DELETED,
		bar => DELETED,
		'subdir/file' => DELETED,
		subdir => DELETED,
	},
	backend => 'Fallback',
);

# Filters can only be tested with the fallback backend.  The other backends
# may merge events and that make it hard to synchronize.

test(
	setup => sub { create_test_files(qw(foo ignoreme)) },
	description => 'scalar filter',
	expected => {
		foo => EXISTS,
	},
	filter => '/foo$',
	backend => 'Fallback',
);

test(
	setup => sub { create_test_files(qw(foo ignoreme)) },
	description => 'regexp filter',
	expected => {
		foo => EXISTS,
	},
	filter => qr{/foo$},
	backend => 'Fallback',
);

test(
	setup => sub { create_test_files(qw(foo ignoreme)) },
	description => 'code reference filter',
	expected => {
		foo => EXISTS,
	},
	filter => sub { shift->path =~ m{/foo$} },
	backend => 'Fallback',
);

done_testing;
