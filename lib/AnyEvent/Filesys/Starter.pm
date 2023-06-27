#! /bin/false

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

sub greet {
	my ($self, $name) = @_;

	$name //= 'world';

	return "Hello, $name!";
}

1;

=head1 NAME

AnyEvent::Filesys::Watch - Perl 5 Starter Project

=head1 SYNOPSIS

    use AnyEvent::Filesys::Watch;

    my $starter = AnyEvent::Filesys::Watch->new(verbose => 1);

=head1 DESCRIPTION

This module is a Template for starting a Perl 5 project.

=head1 CONSTRUCTORS

The following constructors are available:

=over 4

=item B<new(OPTIONS)>

Creates a new B<AnyEvent::Filesys::Watch>.  B<OPTIONS> is a hash of named options.

=over 8

=item B<verbose>

Switches on verbose mode.

=back

=back 

=head1 METHODS

The public API consists of the following methods:

=over 4

=item B<hello([NAME])

Returns a greeting.  B<NAME> defaults to 'world'.

=back

=head1 BUGS

None known.

=head1 AUTHOR

P<AnyEvent::Filesys::Watch> was written by L<Guido Flohr|http://www.guido-flohr.net/>.

=head1 SEE ALSO

perl(1)
