package AnyEvent::Filesys::Watcher::ReadDirectoryChanges;

use strict;

use Locale::TextDomain ('AnyEvent-Filesys-Watcher');

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
				$self->_processEvents();
			}
		}
	);
	if (!$timer) {
		die __x("Error creating timer: {error}\n", error => $@);
	}

	bless $self, $class;

	return $self;
}

1;
