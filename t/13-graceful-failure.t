use Test::More;
use Test::Exception;
use strict;
use warnings;

use AnyEvent::Filesys::Watcher;

use Test::Without::Module qw(Linux::Inotify2 Mac::FSEvents IO::KQueue);

if ($^O ne 'linux' && $^O ne 'darwin'
    && $^O !~ /bsd/i) {
    plan skip_all => 'only for Linux, Mac OS, and BSD';
}

my $w = AnyEvent::Filesys::Watcher->new(
	directories => ['t'],
	callback => sub { },
);
isa_ok $w, 'AnyEvent::Filesys::Watcher', 'graceful fallback';
isa_ok $w, 'AnyEvent::Filesys::Watcher::Fallback', 'to Fallback backend';

throws_ok {
	$w = AnyEvent::Filesys::Watcher->new(
		directories => ['t'],
		callback => sub { },
		backend => 'Inotify2',
	);
} qr/Can't locate/, 'explicitely requested';

done_testing;
