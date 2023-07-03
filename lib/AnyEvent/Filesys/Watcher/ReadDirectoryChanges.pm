package AnyEvent::Filesys::Watcher::ReadDirectoryChanges;

use strict;

use AnyEvent;

use Filesys::Notify::Win32::ReadDirectoryChanges;

use base qw(AnyEvent::Filesys::Watcher);

sub new {
	my ($class, %args) = @_;

	my $self = $class->SUPER::_new(%args);

	my $watcher = Filesys::Notify::Win32::ReadDirectoryChanges->new;
	foreach my $directory (@{$self->directories}) {
		$watcher->watch_directory(path => $directory, subtree => 1);
	}

	my $timer = AnyEvent->timer(
		after => $self->interval,
		interval => $self->interval,
		cb => sub {
			if ($watcher->queue->pending) {
				my @events = $watcher->queue->dequeue;
				$self->_processEvents(@events);
			}
		}
	);
	if (!$timer) {
		die __x("Error creating timer: {error}\n", error => $@);
	}

	$self->_watcher($timer);

	return $self;
}

1;
