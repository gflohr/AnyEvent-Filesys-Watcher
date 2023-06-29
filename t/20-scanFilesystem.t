use Test::More;

use strict;
use warnings;
use lib 't/lib';
use Data::Dump;

use TestSupport qw(create_test_files delete_test_files move_test_files
	modify_attrs_on_test_files $dir);
use AnyEvent::Filesys::Watcher;

# Setup for tests
create_test_files(qw(1 one/1 two/1));

my $old_fs = AnyEvent::Filesys::Watcher->_scanFilesystem($dir, "$dir/one");
is(keys %$old_fs, 6, '_scanFilesystem: got all of them');

create_test_files(qw(2 one/2 two/2));
my $new_fs = AnyEvent::Filesys::Watcher->_scanFilesystem([$dir]);
is(keys %$new_fs, 9, '_scanFilesystem: got all of them');

my @events = AnyEvent::Filesys::Watcher->_diffFilesystem( $old_fs, $new_fs );
is(@events, 3, '_diffFilesystem: got create events') or diag ddx @events;
is($_->type, 'created', '... correct type') for @events;

$old_fs = $new_fs;
create_test_files(qw(2 one/2 two/2));
$new_fs = AnyEvent::Filesys::Watcher->_scanFilesystem($dir);
@events = AnyEvent::Filesys::Watcher->_diffFilesystem($old_fs, $new_fs);
is(@events, 3, '_diffFilesystem: got modification events') or diag ddx @events;
is($_->type, 'modified', '... correct type') for @events;

$old_fs = $new_fs;
delete_test_files(qw(2 one/2 two/2));
$new_fs = AnyEvent::Filesys::Watcher->_scanFilesystem($dir);
@events = AnyEvent::Filesys::Watcher->_diffFilesystem( $old_fs, $new_fs );
is(@events, 3, '_diffFilesystem: got modification events' ) or diag ddx @events;
is($_->type, 'deleted', '... correct type' ) for @events;

$old_fs = $new_fs;
create_test_files(qw(three/1 two/one/1));
$new_fs = AnyEvent::Filesys::Watcher->_scanFilesystem($dir);
@events = AnyEvent::Filesys::Watcher->_diffFilesystem( $old_fs, $new_fs );
is( @events, 4, '_diffFilesystem: got create dir events' ) or diag ddx @events;
is( $_->type, 'created', '... correct type' ) for @events;

$old_fs = $new_fs;
delete_test_files(qw(three/1 three two/one/1));
$new_fs = AnyEvent::Filesys::Watcher->_scanFilesystem($dir);
@events = AnyEvent::Filesys::Watcher->_diffFilesystem( $old_fs, $new_fs );
is( @events, 3, '_diffFilesystem: got create dir events' ) or diag ddx @events;
is( $_->type, 'deleted', '... correct type' ) for @events;

SKIP: {
	skip "attribute changes not available on Windows", 3
		if $^O eq 'MSWin32';

	$old_fs = $new_fs;
	modify_attrs_on_test_files(qw(1 one));
	$new_fs = AnyEvent::Filesys::Watcher->_scanFilesystem($dir);
	@events = AnyEvent::Filesys::Watcher->_diffFilesystem( $old_fs, $new_fs );
	is(@events, 2, '_diffFilesystem: got attrib modify events') or diag ddx @events;
	is($_->type, 'modified', '... correct type') for @events;
}

done_testing();
