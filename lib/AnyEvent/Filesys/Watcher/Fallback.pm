package AnyEvent::Filesys::Watcher::Fallback;

use strict;

use AnyEvent;

use base qw(AnyEvent::Filesys::Watcher);

sub new {
	my ($class, %args) = @_;

	my $self = $class->SUPER::_new(%args);

	my $impl = AnyEvent->timer(
		after => $self->interval,
		interval => $self->interval,
		cb => sub {
			$self->_processEvents();
		}
	);
	if (!$impl) {
		die __x("Error creating timer: {error}\n", error => $@);
	}

	bless $self, $class;

	$self->_watcher($impl);

	return $self;
}

1;

