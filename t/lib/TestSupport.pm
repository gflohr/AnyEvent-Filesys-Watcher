package TestSupport;

use strict;
use warnings;
use File::Temp qw(tempdir);
use File::Path;
use File::Basename;
use File::Copy qw(move);
use File::Spec;
use Cwd;
use Test::More;
use autodie;

use Exporter qw(import);
our @EXPORT_OK = qw(create_test_files delete_test_files move_test_files
	modify_attrs_on_test_files $dir received_events receive_event
	catch_trailing_events);

# On the Mac, TMPDIR is a symbolic link.  We have to resolve that with
# Cwd::realpath in order to be able to compare paths.
our $dir = Cwd::realpath(tempdir(CLEANUP => 1));
my $size = 1;

sub create_test_files {
	my (@files) = @_;

	for my $file (@files) {
		my $full_file = File::Spec->catfile($dir, $file);
		my $full_dir = dirname($full_file);

		mkpath $full_dir unless -d $full_dir;

		my $exists = -e $full_file;

		open my $fd, ">", $full_file;
		print $fd "Test\n" x $size++ if $exists;
		close $fd;
	}
}

sub delete_test_files {
	my (@files) = @_;

	for my $file (@files) {
		my $full_file = File::Spec->catfile($dir, $file);
		if   (-d $full_file) { rmdir $full_file; }
		else				   { unlink $full_file; }
	}
}

sub move_test_files {
	my (%files) = @_;

	while (my ($src, $dst) = each %files) {
		my $full_src = File::Spec->catfile($dir, $src);
		my $full_dst = File::Spec->catfile($dir, $dst);
		move $full_src, $full_dst;
	}
}

sub modify_attrs_on_test_files {
	my (@files) = @_;

	for my $file (@files) {
		my $full_file = File::Spec->catfile($dir, $file);
		chmod 0750, $full_file or die "Error chmod on $full_file: $!";
	}
}

our @received;
our %expected;
our $cv;

sub receive_event {
	push @received, @_;

	if (@received == keys %expected) {
		# This may miss unexpected events coming in but these events will
		# make the next test case fail.  We should however wait for one second
		# at the end to catch them.
		$cv->send;
	}
}

sub catch_trailing_events {
	my $stop = AnyEvent->condvar;

	# Catch at most 100 events.
	%expected = map { $_ => 1 } (1 .. 100);

	my $count = 0;
	my $t = AnyEvent->timer(
		after => 0.1,
		interval => 0.1,
		cb => sub {
			if (@received) {
				compare_ok(\@received, {}, 'trailing garbage events');
				$stop->send; # Fail fast.
			} elsif (++$count > 10) {
				ok 1, 'no trailing garbage events';
				$stop->send;
			}
		},
	);

	$stop->recv;
}

sub received_events {
	my $setup = shift;
	my $description = shift;

	%expected = @_;

	$cv = AnyEvent->condvar;

	$setup->();

	my $w = AnyEvent->timer(
		after => 20,
		cb => sub { $cv->send });

	$cv->recv;

	compare_ok(\@received, \%expected, $description);
	undef @received;
}

sub compare_ok {
	my ($received, $expected, $description) = @_;
	$description ||= "compare events";

	$description .= ':';

	foreach my $event (@{$received}) {
		my $path = File::Spec->abs2rel($event->path, $dir);
		# This is not portable but good enough for our test cases.  Otherwise
		# we would have to drag in Path::Class as a dependency.
		$path =~ s{\\}{/}g;
		my $expected_type = delete $expected->{$path};
		if (!defined $expected_type) {
			my $type = $event->type;
			ok 0, "$description $path: unexpected event of type $type";
			next;
		}
		is $event->type, $expected_type, "$description $path";
	}

	foreach my $path (keys %$expected) {
		ok 0, "$description $path: no event received";
	}
}

1;
