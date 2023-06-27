package AnyEvent::Filesys::Watch::Backend::Fallback;

use AnyEvent;

sub new {
	my ($class, $watch) = @_;

	my $impl = AnyEvent->timer(
		after => $watch->interval,
		interval => $watch->interval,
		cb => sub {
			$watch->_processEvents();
		}
	);
	if (!$impl) {
		die __x("Error creating timer: {error}\n", error => $@);
	}

	bless $impl, $class;
}

1;

