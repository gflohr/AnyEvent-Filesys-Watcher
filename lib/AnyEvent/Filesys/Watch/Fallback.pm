package AnyEvent::Filesys::Watch::Backend::Fallback;

use AnyEvent;

sub implementation {
	my (undef, $watch) = @_;

	my $impl = AnyEvent->timer(
		after => $self->interval,
		interval => $self->interval,
		cb => sub {
			$self->_process_events();
		}
	);
	if (!$impl) {
		require Carp;
		Carp::croak(__x("Error creating timer: {error}", error => $@));
	}

	return $impl;
}

1;
