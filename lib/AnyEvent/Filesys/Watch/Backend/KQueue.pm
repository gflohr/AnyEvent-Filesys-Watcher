package AnyEvent::Filesys::Watch::Backend::KQueue;

use strict;

use AnyEvent;
use IO::KQueue;
use Errno qw(:POSIX);

use Locale::TextDomain ('AnyEvent-Filesys-Watch');

# Arbitrary limit on open filehandles before issuing a warning
our $WARN_FILEHANDLE_LIMIT = 50;

sub new {
	my ($class, $watch) = @_;

	my $kqueue = IO::KQueue->new;
	if (!$kqueue) {
		require Carp;
		Carp::croak(
			__x("Unable to create new IO::KQueue object: {error}",
			    error => $!)
		);
	}
	$watch->_filesystemMonitor($kqueue);

	# Need to add all the subdirs to the watch list, this will catch
	# modifications to files too.
	my $old_fs = $watch->_oldFilesystem;
	my @paths  = keys %$old_fs;

	my $fhs = {};
	my $self = bless {
		fhs => $fhs,
	}, $class;

	# Add each file and each directory to a hash of path => fh
	for my $path (@paths) {
		my $fh = $self->__watch($watch, $path);
		$fhs->{$path} = $fh if defined $fh;
	}

	# Now use AE to watch the KQueue
	my $w;
	$w = AE::io $$kqueue, 0, sub {
		if (my @events = $kqueue->kevent) {
			$watch->_processEvents(@events);
		}
	};
	$self->{w} = $w;

	$self->_checkFilehandleCount;

	return $self;
}

# Need to add newly created items (directories and files) or remove deleted
# items.  This isn't going to be perfect. If the path is not canonical then we
# won't deleted it.  This is done after filtering. So entire dirs can be
# ignored efficiently.
sub _postProcessEvents {
	my ($self, $watch, @events) = @_;

	for my $event (@events) {
		if ($event->isCreated) {
			my $fh = $self->__watch($watch, $event->path);
			$self->{fhs}->{$event->path} = $fh if defined $fh;
		} elsif ($event->isDeleted) {
			delete $self->{fhs}->{$event->path};
		}
	}

	$self->_checkFilehandleCount;

	return;
}

sub __watch {
	my ($self, $watch, $path) = @_;

	open my $fh, '<', $path or do {
		if ($! == EMFILE) {
			warn __(<<'EOF');
KQueue requires a filehandle for each watched file and directory.
You have exceeded the number of filehandles permitted by the OS.
EOF
			return;
		}

		require Carp;
		Carp::confess(
			__x("Cannot open file '{path}': {error}",
			    path => $path, error => $!)
		);
	};

	$watch->_filesystemMonitor->EV_SET(
		fileno($fh),
		EVFILT_VNODE,
		EV_ADD | EV_ENABLE | EV_CLEAR,
		NOTE_DELETE | NOTE_WRITE | NOTE_EXTEND | NOTE_ATTRIB | NOTE_LINK |
			NOTE_RENAME | NOTE_REVOKE,
	);

	return $fh;
}

sub _checkFilehandleCount {
	my ($self) = @_;

	my $count = $self->_watcherCount;
	if ($count > $WARN_FILEHANDLE_LIMIT) {
		require Carp;
		Carp::confess(__x(<<'EOF', count => $count));
KQueue requires a filehandle for each watched file and directory.
You currently have {count} filehandles for this AnyEvent::Filesys::Watch object.
The use of the KQueue backend is not recommended.
EOF
	}

	return $count;
}

sub _watcherCount {
	my ($self) = @_;
	my $fhs = $self->{fhs};
	return scalar keys %$fhs;
}

1;
