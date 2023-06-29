use Test::More;

# GitHub issue #2.

use strict;
use warnings;
use File::Spec;
use lib 't/lib';
$|++;

use TestSupport qw(create_test_files $dir received_events receive_event);

use AnyEvent::Filesys::Watcher;
use AnyEvent::Impl::Perl;

create_test_files(qw(one/1));
## ls: one/1 

my $n = AnyEvent::Filesys::Watcher->new(
	directories => File::Spec->catfile($dir, 'one'),
	callback => sub { receive_event(@_) },
	parse_events => 1,
);
isa_ok($n, 'AnyEvent::Filesys::Watcher');

diag "This might take a few seconds to run...";

received_events(sub { create_test_files(qw(one/2)) },
	'create file', qw(created));

ok(1, '... arrived');

done_testing;
