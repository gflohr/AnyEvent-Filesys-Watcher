# GitHub issue #2.

use strict;
use warnings;

use Test::More;
use File::Spec;

use AnyEvent::Filesys::Watcher;
use lib 't/lib';
use TestSupport qw(create_test_files $dir received_events receive_event
	catch_trailing_events EXISTS DELETED);

$|++;

create_test_files qw(one/1);
## ls: one/1

my $n = AnyEvent::Filesys::Watcher->new(
	directories => File::Spec->catfile($dir, 'one'),
	callback => sub { receive_event(@_) },
);
isa_ok $n, 'AnyEvent::Filesys::Watcher';

diag "This might take a few seconds to run...";

received_events(sub { create_test_files(qw(one/2)) },
	'create file',
	'one/2' => EXISTS,
);

catch_trailing_events;
done_testing;
