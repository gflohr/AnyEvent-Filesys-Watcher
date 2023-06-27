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
}

1;
