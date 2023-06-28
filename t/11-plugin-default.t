use Test::More tests => 6;
use Test::Exception;
use strict;
use warnings;

use AnyEvent::Filesys::Watch;

use Test::Without::Module qw(Linux::Inotify2 Mac::FSEvents IO::KQueue);

my $w = AnyEvent::Filesys::Watch->new(
	directories => ['t'],
	callback => sub { },
	backend => 'Fallback',
);
isa_ok $w, 'AnyEvent::Filesys::Watch';
is $w->backendClass, 'AnyEvent::Filesys::Watch::Backend::Fallback',  '... Fallback';
isnt $w->backendClass, 'AnyEvent::Filesys::Watch::Backend::Inotify2', '... Inotify2';
isnt $w->backendClass, 'AnyEvent::Filesys::Watch::Backend::FSEvents', '... FSEvents';
isnt $w->backendClass, 'AnyEvent::Filesys::Watch::Backend::KQueue',   '... KQueue';

SKIP: {
	skip 'Test for Mac/Linux/BSD only', 1
		unless $^O eq 'linux'
		or $^O eq 'darwin'
		or $^O =~ /bsd/;

	throws_ok {
		AnyEvent::Filesys::Watch->new(
			directories => ['t'],
			callback => sub { }
		);
	}
	qr/you may need to install the [_0-9a-zA-Z:]+ module/, 'fails ok';
}

done_testing;
