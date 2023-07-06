use strict;

use Test::More;

# FIXME! This test should later run on MS-DOS only because it is not needed
# for other systems.

use_ok 'AnyEvent::Filesys::Watcher';
use_ok 'AnyEvent::Filesys::Watcher::ReadDirectoryChanges::Queue';

my $q = AnyEvent::Filesys::Watcher::ReadDirectoryChanges::Queue->new;
ok $q, 'instantiated';
isa_ok $q, 'AnyEvent::Filesys::Watcher::ReadDirectoryChanges::Queue';

my $handle = $q->handle;
ok $handle, 'handle';
isa_ok $handle, 'IO::Handle';

$q->enqueue('foo', 'bar');

is $q->pending, 2, '2 items pending';

my @items = $q->dequeue(2);
is $items[0], 'foo', 'dequeued foo';
is $items[1], 'bar', 'dequeued bar';
is $q->pending, 0, '0 items pending';

done_testing;
