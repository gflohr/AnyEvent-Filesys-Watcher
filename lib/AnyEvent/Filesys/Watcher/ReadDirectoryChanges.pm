package AnyEvent::Filesys::Watcher::ReadDirectoryChanges;

use strict;

use Locale::TextDomain ('AnyEvent-Filesys-Watcher');

use AnyEvent;
use Filesys::Notify::Win32::ReadDirectoryChanges;
use Scalar::Util qw(weaken);
use File::Spec;
use AnyEvent::Filesys::Watcher::Event;

use base qw(AnyEvent::Filesys::Watcher);

sub new {
	my ($class, %args) = @_;

	my $self = $class->SUPER::_new(%args);

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
			if ($watcher->queue->pending) {
				my @events = $watcher->queue->dequeue;
				@events = $self->__processEvents(@events);
				$alter_ego->_processEvents(@events);
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

sub __processEvents {
	my ($self, @all_events) = @_;

	# We want to make sure that only one event gets fired for each file.
	# It is assumed that the last event fired always gives the final state.
	#
	# FIXME! This is not good. Instead allow multiple events for one
	# path but just split the rename thing into two events.
	my %state;
	my @events;
	foreach my $event (reverse @all_events) {
		my $action = $event->{action};

		if ('renamed' eq $action) {
			if (!exists $state{$event->{old_name}}) {
				push @events, AnyEvent::Filesys::Watcher::Event->new(
					$self->_stat($event->{old_name}),
					action => 'deleted',
				);
				$state{$event->{old_name}} = 'deleted';
			}
			if (!exists $state{$event->{new_name}}) {
				push @events, AnyEvent::Filesys::Watcher::Event->new(
					$self->_stat($event->{new_name}),
					type => 'created',
				);
				$state{$event->{new_name}} = 'created';
			}
		} else {
			my $path = $event->{path};
			next if exists $state{$path};

			if ('added' eq $action) {
				$action = 'created';
			} elsif ('removed' eq $action) {
				$action = 'deleted';
			} elsif ('modified' ne $action) {
				die __x("unknown action '{action}' for path '{path}'"
				        . " (should not happen)",
				        action => $action, path => $path);
			}
			push @events, AnyEvent::Filesys::Watcher::Event->new(
				$self->_stat($path),
				type => $action,
			);
			$state{$path} = $action;
		}
	}

	return @events;
}

1;
