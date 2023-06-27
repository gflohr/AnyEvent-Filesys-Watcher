#! /bin/false

# This next lines is here to make Dist::Zilla happy.
# ABSTRACT: Watch file system for changes

package AnyEvent::Filesys::Watch;

use strict;
use v5.10;

use Locale::TextDomain ('AnyEvent-Filesys-Watch');
use Scalar::Util qw(reftype);

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
	} elsif ($^O eq 'linux' ) {
		$backend_class = 'AnyEvent::Filesys::Watch::Backend::Inotify2';
	} elsif ($^O eq 'darwin' ) {
		$backend_class = "AnyEvent::Filesys::Watch::Backend::FSEvents";
	} elsif ($^O =~ /bsd/ ) {
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

1;
