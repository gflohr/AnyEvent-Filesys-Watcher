use Test::More;
use Test::Exception;
use strict;
use warnings;

use AnyEvent::Filesys::Watch;

my $AEFW = 'AnyEvent::Filesys::Watch';

subtest 'Try to load the correct backend for this O/S' => sub {
	if  ($^O eq 'linux' and eval { require Linux::Inotify2; 1 }) {
		my $w = AnyEvent::Filesys::Watch->new (dirs => ['t'], cb => sub { });
		isnt $w->backendClass, "${AEFW}::Backend::Fallback", '... Fallback';
		is $w->backendClass, "${AEFW}::Backend::Inotify2", '... Inotify2';
		isnt $w->backendClass, "${AEFW}::Backend::FSEvents", '... FSEvents';
		isnt $w->backendClass, "${AEFW}::Backend::KQueue", '... KQueue';
	} elsif (
		$^O eq 'darwin' and eval {
			require Mac::FSEvents;
			1;
		}) {
		my $w = AnyEvent::Filesys::Watch->new (dirs => ['t'], cb => sub { });
		isnt $w->backendClass, "${AEFW}::Backend::Fallback", '... Fallback';
		isnt $w->backendClass, "${AEFW}::Backend::Inotify2", '... Inotify2';
		is $w->backendClass, "${AEFW}::Backend::FSEvents", '... FSEvents';
		isnt $w->backendClass, "${AEFW}::Backend::KQueue", '... KQueue';
	} elsif (
		$^O =~ /bsd/ and eval {
			require IO::KQueue;
			1;
		}) {
		my $w = AnyEvent::Filesys::Watch->new (dirs => ['t'], cb => sub { });
		isnt $w->backendClass, "${AEFW}::Backend::Fallback", '... Fallback';
		isnt $w->backendClass, "${AEFW}::Backend::Inotify2", '... Inotify2';
		isnt $w->backendClass, "${AEFW}::Backend::FSEvents", '... FSEvents';
		is $w->backendClass, "${AEFW}::Backend::KQueue", '... KQueue';
	} else {
		my $w = AnyEvent::Filesys::Watch->new (dirs => ['t'], cb => sub { });
		is $w->backendClass, "${AEFW}::Backend::Fallback", '... Fallback';
		isnt $w->backendClass, "${AEFW}::Backend::Inotify2", '... Inotify2';
		isnt $w->backendClass, "${AEFW}::Backend::FSEvents", '... FSEvents';
		isnt $w->backendClass, "${AEFW}::Backend::KQueue", '... KQueue';
	}
};

subtest 'Try to load the fallback backend via no_external' => sub {
	my $w = AnyEvent::Filesys::Watch->new(
		dirs  => ['t'],
		cb   => sub { },
		no_external => 1,
	);

	isa_ok ($w, $AEFW);
	is $w->backendClass, "${AEFW}::Backend::Fallback", '... Fallback';
	isnt $w->backendClass, "${AEFW}::Backend::Inotify2", '... Inotify2';
	isnt $w->backendClass, "${AEFW}::Backend::FSEvents", '... FSEvents';
	isnt $w->backendClass, "${AEFW}::Backend::KQueue", '... KQueue';
};

subtest 'Try to specify Fallback via the backend argument' => sub {
	my $w = AnyEvent::Filesys::Watch->new(
		dirs => ['t'],
		cb  => sub { },
		backend => 'Fallback',
	);
	isa_ok ($w, $AEFW);
	is $w->backendClass, "${AEFW}::Backend::Fallback", '... Fallback';
	isnt $w->backendClass, "${AEFW}::Backend::Inotify2", '... Inotify2';
	isnt $w->backendClass, "${AEFW}::Backend::FSEvents", '... FSEvents';
	isnt $w->backendClass, "${AEFW}::Backend::KQueue", '... KQueue';
};

subtest 'Try to specify +AEFWBR::Fallback via the backend argument' => sub {
	my $w = AnyEvent::Filesys::Watch->new(
		dirs => ['t'],
		cb  => sub { },
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
			AnyEvent::Filesys::Watch->new(
				dirs => ['t'],
				cb  => sub { },
				backend => 'KQueue'
			);
		};
		isa_ok ($w, $AEFW);
		isnt $w->backendClass, "${AEFW}::Backend::Fallback", '... Fallback';
		isnt $w->backendClass, "${AEFW}::Backend::Inotify2", '... Inotify2';
		isnt $w->backendClass, "${AEFW}::Backend::FSEvents", '... FSEvents';
		is $w->backendClass, "${AEFW}::Backend::KQueue", '... KQueue';
	}
}

done_testing;
