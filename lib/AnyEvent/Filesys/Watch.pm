#! /bin/false

# This next lines is here to make Dist::Zilla happy.
# ABSTRACT: Watch file system for changes 

package AnyEvent::Filesys::Watch;

use strict;
use v5.10;

sub new {
	my ($class, %args) = @_;

	my $self = {};
	foreach my $arg (keys %args) {
		$self->{'__' . $arg} = $args{$arg};
	}

	bless $self, $class;
}

1;
