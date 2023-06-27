use strict;

use Test::More tests => 2;

use_ok 'AnyEvent::Filesys::Watch';

my $instance = AnyEvent::Filesys::Watch->new(dirs => '.', cb => sub {});
ok $instance;
