package AnyEvent::Filesys::Watch::Event;

use strict;

use Locale::TextDomain ('AnyEvent-Filesys-Watch');

sub new {
	my ($class, %args) = @_;

	my @required = qw(path type);
	foreach my $required (@required) {
		if (!exists $args{$required}) {
			require Carp;
			Carp::croak(
				__x("Mandatory argument '{arg}' missing",
				    arg => $required)
			);
		}
	}

	if ($args{type} ne 'created'
	    && $args{type} ne 'modified'
	    && $args{type} ne 'deleted') {
			require Carp;
			Carp::croak(
				__x("Type must be one of 'created', 'modified', 'deleted' but"
				    . " not {type}",
				    type => $args{type})
			);
	}

	my $self = {};
	foreach my $arg (keys %args) {
		$self->{'__' . $arg} = $args{$arg};
	}

	bless $self, $class;
}

sub path {
	shift->{__path};
}

sub type {
	shift->{__type};
}

sub isDirectory {
	shift->{__is_directory};
}

sub isCreated {
	return 'created' eq shift->{__type};
}

sub isModified {
	return 'modified' eq shift->{__type};
}

sub isDeleted {
	return 'deleted' eq shift->{__type};
}

1;
