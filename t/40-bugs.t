use Test::More tests => 2;

use strict;
use warnings;

use AnyEvent::Filesys::Watch::Event;

my $e = AnyEvent::Filesys::Watch::Event->new(
	path => 'some/path',
	type => 'modified',
	is_directory => undef,
);

isa_ok($e, "AnyEvent::Filesys::Watch::Event" );
ok(!$e->isDirectory, 'isDirectory');
