#! /bin/false

# This next lines is here to make Dist::Zilla happy.
# ABSTRACT: Watch file system for changes

package AnyEvent::Filesys::Watcher;

use strict;

use Locale::TextDomain ('AnyEvent-Filesys-Watcher');
use Scalar::Util qw(reftype);
use Path::Iterator::Rule;
use Cwd qw(abs_path);

use AnyEvent::Filesys::Watcher::Event;

# We remember which modules we have already unsuccessfully required
# so that we can avoid the "Attempt to reload xyz.pm aborted".
my %losers;

# This constructor is kind of doing reversed inheritance.  It first sets up
# the module, then selects a backend which is then instantiated.  The
# backend is expected to invoke the protected constructor _new() below.
#
# Using the factory pattern would be the cleaner approach but we want to
# retain a certain compatibility with the original AnyEvent::Filesys::Notify,
# because the module is easier to use that way.
sub new {
	my ($class, %args) = @_;

	my $backend_class = $args{backend};

	if (exists $args{cb} && !exists $args{callback}) {
		$args{callback} = delete $args{cb};
	}

	if ($backend_class) {
		# Use the AEFW:: prefix unless the backend starts with a plus.
		unless ($backend_class =~ s/^\+//) {
			$backend_class = "AnyEvent::Filesys::Watcher::"
				. $backend_class;
		}
	} elsif ($^O eq 'linux') {
		$backend_class = 'AnyEvent::Filesys::Watcher::Inotify2';
	} elsif ($^O eq 'darwin') {
		$backend_class = "AnyEvent::Filesys::Watcher::FSEvents";
	} elsif ($^O eq 'MSWin32') {
		$backend_class = "AnyEvent::Filesys::Watcher::ReadDirectoryChanges";
	} elsif ($^O =~ /bsd/) {
		$backend_class = "AnyEvent::Filesys::Watcher::KQueue";
	} else {
		$backend_class = "AnyEvent::Filesys::Watcher::Fallback";
	}

	my $backend_module = $backend_class . '.pm';
	$backend_module =~ s{::}{/}g;

	my $self;
	eval {
		if (exists $losers{$backend_module}) {
			die $losers{$backend_module};
		} else {
			require $backend_module;
			$self = $backend_class->new(%args);
		}
	};
	if ($@) {
		# Remember the exception so that we can re-throw it in case an attempt
		# is made to require the same module again.
		$losers{$backend_module} = $@;

		# Explicitely requested?
		if (exists $args{backend}
		    || 'AnyEvent::Filesys::Watcher::Fallback' eq $backend_class) {
			die $@ if exists $args{backend};
		}

		require AnyEvent::Filesys::Watcher::Fallback;
		$self = AnyEvent::Filesys::Watcher::Fallback->new(%args);
	}

	return $self;
}

sub _new {
	my ($class, %args) = @_;

	my $self = bless {}, $class;

	if (exists $args{cb} && !exists $args{callback}) {
		$args{callback} = delete $args{cb};
	}

	my @required = qw(directories callback);
	foreach my $required (@required) {
		if (!exists $args{$required}) {
			require Carp;
			Carp::croak(
				__x("Mandatory argument '{arg}' missing",
				    arg => $required)
			);
		}
	}

	$args{interval} = 1 if !exists $args{interval};
	$args{directories} = [$args{directories}]
		if !ref $args{directories};
	if (exists $args{filter}
	    && defined $args{filter}
	    && length $args{filter}) {
		$args{filter} = $self->__compileFilter($args{filter});
	} else {
		$args{filter} = sub { 1 };
	}

	foreach my $arg (keys %args) {
		$self->{'__' . $arg} = $args{$arg};
	}

	$self->_oldFilesystem($self->_scanFilesystem($self->directories));

	return $self;
}

sub directories {
	my ($self) = @_;

	return [@{$self->{__directories}}];
}

sub interval {
	shift->{__interval};
}

sub callback {
	my ($self, $cb) = @_;

	if (@_ > 1) {
		$self->{__callback} = $cb;
	}

	return $self->{__callback};
}

sub filter {
	my ($self, $filter) = @_;

	if (@_ > 1) {
		$self->{__filter} = $self->__compileFilter($filter);
	}

	return $self->{__filter};
}

sub parseEvents {
	my ($self, $bool) = @_;

	if (@_ > 1) {
		$self->{__parse_events} = $bool;
	}

	return $self->{__parse_events};
}

sub skipSubdirectories {
	shift->{__skip_subdirectories};
}

# Taken from AnyEvent::Filesys::Notify.
sub _scanFilesystem {
	my ($self, @args) = @_;

	# Accept either an array of directories or an array reference of
	# directories.
	my @paths = ref $args[0] eq 'ARRAY' ? @{ $args[0] } : @args;

	my $fs_stats = {};

	my $rule = Path::Iterator::Rule->new;
	$rule->skip_subdirs(qr/./)
		if (ref $self) =~ /^AnyEvent::Filesys::Watcher/
		&& $self->skipSubdirectories;
	my $next = $rule->iter(@paths);
	while (my $file = $next->()) {
		my %stat = $self->_stat($file)
			or next; # Skip files that we cannot stat.
		$fs_stats->{ abs_path $file } = \%stat;
	}

	return $fs_stats;
}

# Taken from AnyEvent::Filesys::Notify.
sub _diffFilesystem {
	my ($self, $old_fs, $new_fs) = @_;
	my @events = ();

	for my $path (keys %$old_fs) {
		if (not exists $new_fs->{$path}) {
			push @events,
				AnyEvent::Filesys::Watcher::Event->new(
					path => $path,
					type => 'deleted',
					is_directory => $old_fs->{$path}->{is_directory},
				);
		} elsif ($self->__isPathModified($old_fs->{$path}, $new_fs->{$path})) {
			push @events,
				AnyEvent::Filesys::Watcher::Event->new(
					path => $path,
					type => 'modified',
					is_directory => $old_fs->{$path}->{is_directory},
			);
		}
	}

	for my $path (keys %$new_fs) {
		if (not exists $old_fs->{$path}) {
			push @events,
				AnyEvent::Filesys::Watcher::Event->new(
					path => $path,
					type => 'created',
					is_directory => $new_fs->{$path}->{is_directory},
				);
		}
	}

	return @events;
}

sub _filesystemMonitor {
	my ($self, $value) = @_;

	if (@_ > 1) {
		$self->{__filesystem_monitor} = $value;
	}

	return $self->{__filesystem_monitor};
}

sub _watcher {
	my ($self, $watcher) = @_;

	if (@_ > 1) {
		$self->{__watcher} = $watcher;
	}

	return $self->{__watcher};
}

sub _processEvents {
	my ($self, @raw_events) = @_;

	# Some implementations provided enough information to parse the raw events,
	# other require rescanning the file system (ie, Mac::FSEvents).
	# have added a flag to avoid breaking old code.
	my @events;
	if ($self->parseEvents and $self->can('_parseEvents') ) {
		@events =
			$self->_parseEvents(
				sub { $self->_applyFilter(@_) },
				@raw_events
			);
	} else {
		my $new_fs = $self->_scanFilesystem($self->directories);

		@events = $self->_applyFilter(
	 		$self->_diffFilesystem($self->_oldFilesystem, $new_fs));
		$self->_oldFilesystem($new_fs);

		$self->_postProcessEvents(@events);
	}

	$self->callback->(@events) if @events;

	return \@events;
}

# Some backends (when not using parse_events) need to add files
# (KQueue) or directories (Inotify2) to the watch list after they are
# created. Give them a chance to do that here.
sub _postProcessEvents {}

sub _applyFilter {
	my ($self, @events) = @_;

$DB::single = 1;
	my $cb = $self->filter;
	return grep { $cb->($_) } @events;
}

sub _oldFilesystem {
	my ($self, $fs) = @_;

	if (@_ > 1) {
		$self->{__old_filesystem} = $fs;
	}

	return $self->{__old_filesystem};
}

sub _directoryWrites {
	shift->{__directory_writes};
}

sub __compileFilter {
	my ($self, $filter) = @_;

	if (!ref $filter) {
		$filter = qr/$filter/;
	}

	my $reftype = reftype $filter;
	if ('REGEXP' eq $reftype) {
		my $regexp = $filter;
		$filter = sub {
			my $event = shift;
			my $path = $event->path;
			my $result = $path =~ $regexp;
			return $result;
		};
	} elsif ($reftype ne 'CODE') {
		require Carp;
		Carp::confess(__("The filter must either be a regular expression or"
						. " code reference"));
	}

	return $filter;
}

# Originally taken from Filesys::Notify::Simple --Thanks Miyagawa
sub _stat {
	my ($self, $path ) = @_;

	my @stat = stat $path;

	# Return undefined if no stats can be retrieved, as it happens with broken
	# symlinks (at least under ext4).
	return unless @stat;

	return (
		path => $path,
		mtime => $stat[9],
		size => $stat[7],
		mode => $stat[2],
		is_directory => -d _,
	);
}

# Taken from AnyEvent::Filesys::Notify.
sub __isPathModified {
	my ($self, $old_path, $new_path) = @_;

	return 1 if $new_path->{mode} != $old_path->{mode};
	return if $new_path->{is_directory};
	return 1 if $new_path->{mtime} != $old_path->{mtime};
	return 1 if $new_path->{size} != $old_path->{size};
	return;
}

1;
