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
			if ($watcher->queue->pending) {
				my @raw_events = $watcher->queue->dequeue;
				my @events = $alter_ego->_transformEvents(@raw_events);

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

sub _transformEvents {
	my ($self, @all_events) = @_;

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

		if (!File::Spec->file_name_is_absolute($path)) {
			$path = File::Spec->rel2abs($path, $self->{__base_directory});
		}

		push @events, AnyEvent::Filesys::Watcher::Event->new(
			path => $path,
			type => $action,
			is_directory => -d $path,
		);
	}

	@events = $self->__cookEvents(@events);

	return $self->_applyFilter(@events);
}

sub __cookEvents {
	my ($self, @raw_events) = @_;

	my %events;
	my @events;
	my $old_fs = $self->_oldFilesystem;
	RAW_EVENT: for my $i (0 .. $#raw_events) {
		my $event = $raw_events[$i];
		my $type = $event->type;
		my $path = $event->path;

		if ('modified' eq $type) {
			if ($event->isDirectory) {
				# Only MS-DOS reports changes to the directories, when the
				# contents of the directory changes.  This is technically
				# correct but all other backends do not report this event.
				next;
			} elsif ($events{$path} && 'created' eq $events{$path}->type) {
				# The fallback backend only reports a 'created' event.
				next;
			}
		} elsif ('deleted' eq $type) {
			# If a file is renamed to an existing file, then a 'delete', and
			# then a 'create' event is triggered.  In this case, we want to
			# ignore the gratuituous 'delete' event, and change the 'created'
			# to 'modified'.
			foreach my $j ($i + 1 .. $#raw_events) {
				my $other = $raw_events[$j];
				if ('created' eq $other->type
					&& $path eq $other->type
					&& !!$event->isDirectory == !!$other->isDirectory) {
					$raw_events[$j] = AnyEvent::Filesys::Watcher::Event->new(
						path => $path,
						type => 'modified',
						is_directory => $event->isDirectory,
					);
					next RAW_EVENT;
				}
			}
		}

		push @events, $event;
		$events{$path} = $event;
	}

	return @events;
}

1;
