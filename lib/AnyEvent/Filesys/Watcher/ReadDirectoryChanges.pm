package AnyEvent::Filesys::Watcher::ReadDirectoryChanges;

use strict;

use Locale::TextDomain ('AnyEvent-Filesys-Watcher');

use AnyEvent;
use Filesys::Notify::Win32::ReadDirectoryChanges;
use Scalar::Util qw(weaken);
use File::Spec;
use Cwd;
use AnyEvent::Filesys::Watcher::Event;

use base qw(AnyEvent::Filesys::Watcher);

sub new {
	my ($class, %args) = @_;

	my $self = $class->SUPER::_new(%args);

	$self->{__base_directory} = Cwd::cwd();
	my $watcher = Filesys::Notify::Win32::ReadDirectoryChanges->new;
	foreach my $directory (@{$self->directories}) {
		eval {
			$watcher->watch_directory(path => $directory, subtree => 1);
		};
		if ($@) {
			die __x("Error watching directory '{path}': {error}.\n",
			        path => $directory, error => $@);
		}
	}

	my $alter_ego = $self;
	my $timer = AnyEvent->timer(
		after => $self->interval,
		interval => $self->interval,
		cb => sub {
			my $pending = $watcher->queue->pending;
			if ($pending) {
				my @raw_events = $watcher->queue->dequeue($pending);

				$alter_ego->_processEvents(
					@raw_events
				);
			}
		}
	);
	weaken $alter_ego;
	if (!$timer) {
		die __x("Error creating timer: {error}\n", error => $@);
	}

	$self->_watcher($timer);

	return $self;
}

sub _parseEvents {
	my ($self, $filter, @all_events) = @_;

	my %events;
	my @events;
	for my $event (@all_events) {
		my $action = $event->{action};
		my $path = $event->{path};

		if ('removed' eq $action || 'old_name' eq $action) {
			$action = 'deleted';
		} elsif ('added' eq $action || 'new_name' eq $action) {
			$action = 'created';
		} elsif ('renamed' eq $action) {
			# Not needed.
			next;
		} elsif ('unknown' eq $action) {
			die __"Error: Probably too many files inside watched directories.\n";
		} elsif ('modified' ne $action) {
			die __x("unknown action '{action}' for path '{path}'"
					. " (should not happen)",
					action => $action, path => $path);
		}

		$path = $self->_makeAbsolute($path);

		my $cooked = AnyEvent::Filesys::Watcher::Event->new(
			path => $path,
			type => $action,
			is_directory => -d $path,
		);
		push @events, $cooked if $filter->($cooked);
	}

	return @events;
}

1;
