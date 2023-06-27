use strict;
use v5.10;

use Test::More tests => 3;

use_ok 'AnyEvent::Filesys::Watch', 'module loads';

my $instance = AnyEvent::Filesys::Watch->new;

ok $instance, 'instantiated';
is $instance->greet('Jane Appleseed'), 'Hello, Jane Appleseed!', 'greeting';
