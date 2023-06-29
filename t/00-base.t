use strict;

use Test::More tests => 2;

use_ok 'AnyEvent::Filesys::Watcher';

my $instance = AnyEvent::Filesys::Watcher->new(
	directories => ['.'],
	callback => sub {}
);
ok $instance;
