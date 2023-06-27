package AnyEvent::Filesys::Watch::Backend::FSEvents;

use AnyEvent;
use Mac::FSEvents;

sub new {
	my ($class, $watch) = @_;

	# Created a new Mac::FSEvents fs_monitor for each dir to watch.
	my @fs_monitors =
		map { Mac::FSEvents->new( { path => $_, latency => $watch->interval, } ) }
	@{$watch->directories};

	# Create an AnyEvent->io watcher for each fs_monitor
	my @watchers;
	for my $fs_monitor (@fs_monitors) {
		my $w = AE::io $fs_monitor->watch, 0, sub {
			if (my @events = $fs_monitor->read_events) {
				$watch->_processEvents(@events);
			}
		};
		push @watchers, $w;
	}

	$watch->_filesystemMonitor(\@fs_monitors);

	my $self = \@watchers;

	bless $self, $class;
}

1;
