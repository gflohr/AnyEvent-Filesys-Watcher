package AnyEvent::Filesys::Watcher::ReadDirectoryChanges;

use strict;

use Locale::TextDomain ('AnyEvent-Filesys-Watcher');

use AnyEvent;
use Filesys::Notify::Win32::ReadDirectoryChanges;

use base qw(AnyEvent::Filesys::Watcher);

sub new {
	my ($class, %args) = @_;

	my $self = $class->SUPER::_new(%args);

	my $timer = AnyEvent->timer(
		after => $self->interval,
		interval => $self->interval,
		cb => sub {
			$self->_processEvents();
		}
	);
	if (!$timer) {
		die __x("Error creating timer: {error}\n", error => $@);
	}

	bless $self, $class;

	$self->_watcher($timer);

	return $self;
}

1;
