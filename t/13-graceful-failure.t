use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Without::Module qw(
	Linux::Inotify2
	Mac::FSEvents
	Filesys::Notify::Win32::ReadDirectoryChanges
	IO::KQueue
);

use AnyEvent::Filesys::Watcher;

if ($^O ne 'linux' && $^O ne 'darwin'
    && $^O ne 'MSWin32' && $^O !~ /bsd/i) {
    plan skip_all => 'only for Linux, Mac OS, MS-DOS, and BSD';
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

# Test that the exception was cached so that we don't produce the warning,
# "Attempt to reload xyz.pm aborted."
throws_ok {
	$w = AnyEvent::Filesys::Watcher->new(
		directories => ['t'],
		callback => sub { },
		backend => 'Inotify2',
	);
} qr/Can't locate/, 'no attempt to reload';

done_testing;
