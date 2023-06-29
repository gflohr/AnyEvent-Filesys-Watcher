use Test::More;
use Test::Exception;
use strict;
use warnings;

use AnyEvent::Filesys::Watcher;

my $AEFW = 'AnyEvent::Filesys::Watcher';

subtest 'Try to load the correct backend for this O/S' => sub {
	if  ($^O eq 'linux' and eval { require Linux::Inotify2; 1 }) {
		my $w = AnyEvent::Filesys::Watcher->new (
			directories => ['t'],
			callback => sub { }
		);
		isnt $w->backendClass, "${AEFW}::Backend::Fallback", '... Fallback';
		is $w->backendClass, "${AEFW}::Backend::Inotify2", '... Inotify2';
		isnt $w->backendClass, "${AEFW}::Backend::FSEvents", '... FSEvents';
		isnt $w->backendClass, "${AEFW}::Backend::KQueue", '... KQueue';
	} elsif (
		$^O eq 'darwin' and eval {
			require Mac::FSEvents;
			1;
		}) {
		my $w = AnyEvent::Filesys::Watcher->new (
			directories => ['t'],
			callback => sub { }
		);
		isnt $w->backendClass, "${AEFW}::Backend::Fallback", '... Fallback';
		isnt $w->backendClass, "${AEFW}::Backend::Inotify2", '... Inotify2';
		is $w->backendClass, "${AEFW}::Backend::FSEvents", '... FSEvents';
		isnt $w->backendClass, "${AEFW}::Backend::KQueue", '... KQueue';
	} elsif (
		$^O =~ /bsd/ and eval {
			require IO::KQueue;
			1;
		}) {
		my $w = AnyEvent::Filesys::Watcher->new (
			directories => ['t'],
			callback => sub { }
		);
		isnt $w->backendClass, "${AEFW}::Backend::Fallback", '... Fallback';
		isnt $w->backendClass, "${AEFW}::Backend::Inotify2", '... Inotify2';
		isnt $w->backendClass, "${AEFW}::Backend::FSEvents", '... FSEvents';
		is $w->backendClass, "${AEFW}::Backend::KQueue", '... KQueue';
	} else {
		my $w = AnyEvent::Filesys::Watcher->new (
			directories => ['t'],
			callback => sub { }
		);
		is $w->backendClass, "${AEFW}::Backend::Fallback", '... Fallback';
		isnt $w->backendClass, "${AEFW}::Backend::Inotify2", '... Inotify2';
		isnt $w->backendClass, "${AEFW}::Backend::FSEvents", '... FSEvents';
		isnt $w->backendClass, "${AEFW}::Backend::KQueue", '... KQueue';
	}
};

subtest 'Try to specify Fallback via the backend argument' => sub {
	my $w = AnyEvent::Filesys::Watcher->new(
		directories => ['t'],
		callback => sub { },
		backend => 'Fallback',
	);
	isa_ok ($w, $AEFW);
	is $w->backendClass, "${AEFW}::Backend::Fallback", '... Fallback';
	isnt $w->backendClass, "${AEFW}::Backend::Inotify2", '... Inotify2';
	isnt $w->backendClass, "${AEFW}::Backend::FSEvents", '... FSEvents';
	isnt $w->backendClass, "${AEFW}::Backend::KQueue", '... KQueue';
};

subtest 'Try to specify +AEFWBR::Fallback via the backend argument' => sub {
	my $w = AnyEvent::Filesys::Watcher->new(
		directories => ['t'],
		callback => sub { },
		backend => "+${AEFW}::Backend::Fallback",
	);
	isa_ok ($w, $AEFW);
	is $w->backendClass, "${AEFW}::Backend::Fallback", '... Fallback';
	isnt $w->backendClass, "${AEFW}::Backend::Inotify2", '... Inotify2';
	isnt $w->backendClass, "${AEFW}::Backend::FSEvents", '... FSEvents';
	isnt $w->backendClass, "${AEFW}::Backend::KQueue", '... KQueue';
};

if ($^O eq 'darwin' and eval { require IO::KQueue; 1; }) {
	subtest 'Try to force KQueue on Mac with IO::KQueue installed' => sub {
		my $w = eval {
			AnyEvent::Filesys::Watcher->new(
				directories => ['t'],
				callback => sub { },
				backend => 'KQueue'
			);
		};
		my $x = $@ || 'no exception';
		ok !$@, "$x";
		isa_ok $w, $AEFW;
		isnt $w->backendClass, "${AEFW}::Backend::Fallback", '... Fallback';
		isnt $w->backendClass, "${AEFW}::Backend::Inotify2", '... Inotify2';
		isnt $w->backendClass, "${AEFW}::Backend::FSEvents", '... FSEvents';
		is $w->backendClass, "${AEFW}::Backend::KQueue", '... KQueue';
	}
}

done_testing;
