#! /bin/false

# This next lines is here to make Dist::Zilla happy.
# ABSTRACT: Watch file system for changes

package AnyEvent::Filesys::Watch;

use strict;
use v5.10;

use Locale::TextDomain ('AnyEvent-Filesys-Watch');
use Scalar::Util qw(reftype);
use Path::Iterator::Rule;
use Cwd qw(abs_path);

use AnyEvent::Filesys::Watch::Event;

sub new {
	my ($class, %args) = @_;

	my $self = {};
	bless $self, $class;

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

	$args{interval} = 2 if !exists $args{interval};
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

	$self->__oldFilesystem($self->_scanFilesystem($self->directories));

	$self->__loadBackend;

	return $self;
}

sub backend {
	shift->{__backend};
}

sub backendClass {
	shift->{__backend_class};
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
		$self->{__callback} = $cb;''
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
	shift->{__skip_subdirectories} = @_;
}

# Taken from AnyEvent::Filesys::Notify.
sub _scanFilesystem {
	my ($self, @args) = @_;

	# Accept either an array of directories or a array reference of directories.
	my @paths = ref $args[0] eq 'ARRAY' ? @{ $args[0] } : @args;

	my $fs_stats = {};

	my $rule = Path::Iterator::Rule->new;
	$rule->skip_subdirs(qr/./)
		if (ref $self) =~ /^AnyEvent::Filesys::Watch/
		&& $self->skipDirectories;
	my $next = $rule->iter(@paths);
	while (my $file = $next->()) {
		my $stat = $self->__stat($file)
			or next; # Skip files that we cannot stat.
		$fs_stats->{ abs_path($file) } = $stat;
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
				AnyEvent::Filesys::Watch::Event->new(
					path => $path,
					type => 'deleted',
					is_directory => $old_fs->{$path}->{is_directory},
				);
		} elsif ($self->__isPathModified($old_fs->{$path}, $new_fs->{$path})) {
			push @events,
				AnyEvent::Filesys::Watch::Event->new(
					path => $path,
					type => 'modified',
					is_directory => $old_fs->{$path}->{is_directory},
			);
		}
	}

	for my $path (keys %$new_fs) {
		if (not exists $old_fs->{$path}) {
			push @events,
				AnyEvent::Filesys::Watch::Event->new(
					path => $path,
					type => 'created',
					is_directory => $new_fs->{$path}->{is_directory},
				);
		}
	}

	return @events;
}

sub __oldFilesystem {
	my ($self, $fs) = @_;

	if (@_ > 1) {
		$self->{__old_filesystem} = $fs;
	}

	return $self->{__old_filesystem};
}

sub __compileFilter {
	my ($self, $filter) = @_;

	if (!ref $filter) {
		$filter = qr/$filter/;
	}

	my $reftype = reftype $filter;
	if ('REGEXP' eq $reftype) {
		$filter = sub { shift =~ $filter };
	} elsif ($reftype ne 'CODEREF') {
		require Carp;
		Carp::confess(__("The filter must either be regular expression or"
						. " code reference"));
	}

	return $filter;
}

sub __loadBackend {
	my ($self) = @_;

	my $backend_class;

	if ($self->backend) {
		# Use the AEFW::Backend prefix unless the backend starts with a +
		my $prefix  = "AnyEvent::Filesys::Watch::Backend::";
		$backend_class = $self->backend;
		$backend_class = $prefix . $backend_class
			unless $backend_class =~ s{^\+}{};
	} elsif ($^O eq 'linux') {
		$backend_class = 'AnyEvent::Filesys::Watch::Backend::Inotify2';
	} elsif ($^O eq 'darwin') {
		$backend_class = "AnyEvent::Filesys::Watch::Backend::FSEvents";
	} elsif ($^O =~ /bsd/) {
		$backend_class = "AnyEvent::Filesys::Watch::Backend::KQueue";
	} else {
		$backend_class = "AnyEvent::Filesys::Watch::Backend::Fallback";
	}

	$self->{__backend_class} = $backend_class;

	my $backend_module = $backend_class . '.pm';
	$backend_module =~ s{::}{/}g;

	require $backend_module;
	$self->{__watcher} = $backend_class->new($self);

	return $self;
}

# Originally taken from Filesys::Notify::Simple --Thanks Miyagawa
sub __stat {
	my ($self, $path ) = @_;

	my @stat = stat $path;

	# Return undefined if no stats can be retrieved, as it happens with broken
	# symlinks (at least under ext4).
	return unless @stat;

	return {
		path => $path,
		mtime => $stat[9],
		size => $stat[7],
		mode => $stat[2],
		is_directory => -d _,
	};
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
