package AnyEvent::Filesys::Watcher::ReadDirectoryChanges::Queue;

use strict;

# Once this module works it should be inlined with the MS-DOS backend because
# it is only relevant there.  For the time being, ship it separately, so that
# it can be tested independently.

use Locale::TextDomain ('AnyEvent-Filesys-Watcher');
use Thread::Queue 3.13;

use base qw(Thread::Queue);

1;
