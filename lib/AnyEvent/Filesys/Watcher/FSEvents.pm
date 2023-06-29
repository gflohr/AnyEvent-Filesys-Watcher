package AnyEvent::Filesys::Watcher::FSEvents;

use strict;

use AnyEvent;
use Mac::FSEvents;

use base qw(AnyEvent::Filesys::Watcher);

sub new {
	my ($class, %args) = @_;

	my $self = $class->SUPER::_new(%args);

	# Created a new Mac::FSEvents fs_monitor for each dir to watch.
	my @fs_monitors =
		map { Mac::FSEvents->new( { path => $_, latency => $self->interval, } ) }
	@{$self->directories};

	# Create an AnyEvent->io watcher for each fs_monitor
	my @watchers;
	for my $fs_monitor (@fs_monitors) {
		my $w = AE::io $fs_monitor->watch, 0, sub {
			if (my @events = $fs_monitor->read_events) {
				$self->_processEvents(@events);
			}
		};
		push @watchers, $w;
	}

	$self->_filesystemMonitor(\@fs_monitors);

	$self->_watcher(\@watchers);

	return $self;
}

1;
