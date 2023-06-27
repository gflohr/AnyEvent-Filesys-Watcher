#! /bin/false

# This next lines is here to make Dist::Zilla happy.
# ABSTRACT: Watch file system for changes

package AnyEvent::Filesys::Watch;

use strict;
use v5.10;

use Locale::TextDomain ('AnyEvent-Filesys-Watch');

sub new {
	my ($class, %args) = @_;

	my @required = qw(dirs cb);
	foreach my $required (@required) {
		if (!exists $args{$required}) {
			require Carp;
			Carp::croak(
				__x("Mandatory argument '{arg}' missing",
				    arg => $required)
			);
		}
	}
	my $self = {};
	foreach my $arg (keys %args) {
		$self->{'__' . $arg} = $args{$arg};
	}

	bless $self, $class;

	$self->__loadBackend;

	return $self;
}

sub backend {
	shift->{__backend};
}

sub backendClass {
	shift->{__backend_class};
}

sub no_external {
	require Carp;
	Carp::croak('use noExternal instead of no_external');
}

sub noExternal {
	shift->{__no_external};
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
	} elsif ( $self->noExternal ) {
		$backend_class = "AnyEvent::Filesys::Watch::Backend::Fallback";
	} elsif ( $^O eq 'linux' ) {
		$backend_class = 'AnyEvent::Filesys::Watch::Backend::Inotify2';
	} elsif ( $^O eq 'darwin' ) {
		$backend_class = "AnyEvent::Filesys::Watch::Backend::FSEvents";
	} elsif ( $^O =~ /bsd/ ) {
		$backend_class = "AnyEvent::Filesys::Watch::Backend::KQueue";
	} else {
		$backend_class = "AnyEvent::Filesys::Watch::Backend::Fallback";
	}

	$self->{__backend_class} = $backend_class;

	# TODO! Load the backend!

	return $self;
}

1;
