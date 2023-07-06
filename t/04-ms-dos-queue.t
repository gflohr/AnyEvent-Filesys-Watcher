use strict;

use Test::More;

# FIXME! This test should later run on MS-DOS only because it is not needed
# for other systems.

use_ok 'AnyEvent::Filesys::Watcher';
use_ok 'AnyEvent::Filesys::Watch::ReadDirectoryChanges::Queue';

done_testing;
