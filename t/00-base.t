use strict;

use Test::More tests => 2;

use_ok 'AnyEvent::Filesys::Watch';

my $instance = AnyEvent::Filesys::Watch->new(
	directories => ['.'],
	callback => sub {}
);
ok $instance;
