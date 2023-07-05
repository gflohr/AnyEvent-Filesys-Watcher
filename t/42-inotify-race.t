# GitHub issue https://github.com/mvgrimes/AnyEvent-Filesys-Notify/issues/11.
# Previous implementation had a race condition which could miss entities
# created inside a newly create directory.

use strict;
use warnings;

use File::Spec;
use Test::More;
use Test::Without::Module qw(Filesys::Notify::Win32::ReadDirectoryChanges);

use AnyEvent::Filesys::Watcher;
use lib 't/lib';
use TestSupport qw(create_test_files delete_test_files move_test_files
	modify_attrs_on_test_files $dir received_events receive_event
	catch_trailing_events EXISTS DELETED
	$safe_directory_filter $ignoreme_filter);

$|++;

create_test_files qw(one/1 two/1);
## ls: one/1 two/1

my $n = AnyEvent::Filesys::Watcher->new(
	directories => [ map { File::Spec->catfile($dir, $_) } qw(one two) ],
	filter => $safe_directory_filter,
	callback => sub { receive_event(@_) },
	parse_events => 1,
);
isa_ok $n, 'AnyEvent::Filesys::Watcher';

diag "This might take a few seconds to run...";

received_events(
	sub { create_test_files(qw(one/sub/2)) },
	'create subdir and file',
	'one/sub' => EXISTS,
	'one/sub/2' => EXISTS,
);

## ls: one/sub/1 one/sub/2 two/1
$n->filter($ignoreme_filter);
received_events(
	sub { create_test_files(qw(one/sub/ignoreme/1 one/sub/3)) },
	'create two files in subdir, one ignored',
	'one/sub/3' => EXISTS,
);

## ls: one/sub/1 one/sub/2 one/sub/ignoreme/1 one/sub/3 two/1

received_events(
	sub { create_test_files(qw(two/sub/ignoreme/sub/1)) },
	'create subdir and ignore the rest',
	'two/sub' => EXISTS,
);
$n->filter($safe_directory_filter);

## ls: one/sub/1 one/sub/2 one/sub/ignoreme/1 one/sub/3 two/1 tow/sub/ignoreme/sub/1

catch_trailing_events;
done_testing;
