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
	foreach (@{$self->directories}) {
		# Make sure the original directory does not get overwritten.
		my $directory = $_;
		if (!File::Spec->file_name_is_absolute($directory)) {
			$directory = File::Spec->rel2abs($directory);
		}
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
				my @raw_events = $watcher->queue->dequeue;
				my @events = $alter_ego->_translateEvents(@raw_events);

				# Somethimes, there is a lone "renamed" event which gets
				# ignored.
				$alter_ego->_processEvents(
					@events
				) if @events;
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
	my ($self, $filter, @events) = @_;

	# The events have already been cooked and filtered.

	return @events;
}

sub _translateEvents {
	my ($self, @all_events) = @_;

	my @events;
	for my $event (@all_events) {
		my $action = $event->{action};
		my $path = $event->{path};

		my $is_directory = -d $path;
		if ('removed' eq $action || 'old_name' eq $action) {
			$action = 'deleted';
		} elsif ('added' eq $action || 'new_name' eq $action) {
			# FIXME! Check if the file had been overwritten (modified) or
			# created.
			$action = 'created';
		} elsif ('renamed' eq $action) {
			# Not needed.
			next;
		} elsif ('unknown' eq $action) {
			die __"Error: Probably too many files inside watched directories.\n";
		} elsif ('modified' eq $action) {
			if ($is_directory && !$self->_directoryWrites) {
				# MS-DOS generates modified events for the directory if the
				# contents of the directory has changed.  This is actually
				# correct because the directory file has really changed.  But
				# the other backends do not create such events, and so do
				# we unless explicitely requested.
				next;
			}
		} else {
			die __x("unknown action '{action}' for path '{path}'"
					. " (should not happen)",
					action => $action, path => $path);
		}

		push @events, AnyEvent::Filesys::Watcher::Event->new(
			path => $path,
			type => $action,
			is_directory => -d $path,
		);
	}

	return $self->_applyFilter(@events);
}

1;
