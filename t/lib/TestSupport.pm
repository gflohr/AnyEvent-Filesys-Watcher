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

use constant EXISTS => 1;
use constant DELETED => 0;

use Exporter qw(import);
our @EXPORT = qw(EXISTS DELETED);
our @EXPORT_OK = qw(create_test_files delete_test_files move_test_files
	modify_attrs_on_test_files $dir received_events receive_event
	catch_trailing_events next_testing_done_file EXISTS DELETED
	$safe_directory_filter $ignoreme_filter);

sub create_test_files;
sub delete_test_files;
sub move_test_files;
sub modify_attrs_on_test_files;
sub received_events;
sub receive_event;

# On the Mac, TMPDIR is a symbolic link.  We have to resolve that with
# Cwd::realpath in order to be able to compare paths.
our $dir = Cwd::realpath(tempdir CLEANUP => 1);
my $size = 1;

# The MS-DOS implementation generates modified events for directories, if
# the directory contents changes.  Although technically correct, this
# is not done by the other backends.  This filter therefore filters out
# modified events for directories.
our $safe_directory_filter = sub {
	my ($event) = @_;

	return if $event->isDirectory && 'modified' eq $event->type;

	return 1;
};

our $ignoreme_filter = sub {
	my ($event) = @_;
	
	return if $event->isDirectory && 'modified' eq $event->type;
	return if $event->path =~ m{/ignoreme/};
	return if $event->path =~ m{/ignoreme$};

	return 1;
};

# For the (preliminary) MS-DOS implementation we had to significantly increase
# the waiting timeout at the end of the tests.  Therefore, receive_events()
# now signals that (probably) no more events will be coming by creating a
# file.  If the callback gets a notification for this file it will immediately
# send to the condition variable to stop the test.
#
# If more, unexpected, events would be coming in, the next test will fail.
# Only the last test would be critical because for it, such trailing garbage
# could not be detected.  If that garbage is coming in in reasonable time,
# we will still detected it if catch_trailing_events() is called.  And other
# cases are so unlikely that we will ignore them.
our $test_count = 0;
our $testing_done_format = 'one/testing-done-%u';

sub next_testing_done_file {
	sprintf $testing_done_format, $test_count + 1;
}

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
	my (@events) = @_;

	my $testing_file = sprintf $testing_done_format, $test_count;
	my $ready;
	foreach my $event (@events) {
		if ($event->path =~ m{/$testing_file$}) {
			$ready = 1;
		} else {
			push @received, $event;
		}
	}

	$cv->send if $ready;
}

sub catch_trailing_events {
	my $stop = AnyEvent->condvar;

	# Catch at most 100 events.
	%expected = map { $_ => 1 } (1 .. 100);

	my $count = 0;
	my $t = AnyEvent->timer(
		after => 0.1,
		interval => 0.2,
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

	foreach my $key (keys %expected) {
		my $value = $expected{$key};
		if ($value !~ /^0|1$/) {
			require Carp;
			Carp::croak("use boolean result (0 or 1)");
		}
	}

	$cv = AnyEvent->condvar;

	$setup->();

	my $testing_file = sprintf $testing_done_format, ++$test_count;
	create_test_files $testing_file;

	my $w = AnyEvent->timer(
		after => 20,
		cb => sub {
			ok 0, "$description: lame test case (should not happen)";
			$cv->send;
		});

	$cv->recv;

	compare_ok(\@received, \%expected, $description);
	undef @received;
}

sub compare_ok {
	my ($received, $expected, $description) = @_;
	$description ||= "compare events";

	$description .= ':';

	my %got;
	my %received_events;
	# First translate the events to either EXISTS or DELETED.
	foreach my $event (@{$received}) {
		my $path = File::Spec->abs2rel($event->path, $dir);
		# This is not portable but good enough for our test cases.  Otherwise
		# we would have to drag in Path::Class as a dependency.
		$path =~ s{\\}{/}g;
		my $type = $event->type;
		$received_events{$path} ||= [];
		push @{$received_events{$path}}, $type;

		if ('deleted' eq $type) {
			$got{$path} = DELETED;
		} else {
			$got{$path} = EXISTS;
		}
	}

	# Now match got versus expected.
	foreach my $path (keys %got) {
		my $expected_type = delete $expected->{$path};
		if (!defined $expected_type) {
			my $types = join ', ', @{$received_events{$path}};
			ok 0, "$description $path: unexpected event of type(s) $types";
			next;
		}
		if (!!$expected_type != !!$got{$path}) {
			if ($expected_type) {
				ok 0, "$description $path: expected to be deleted but seems to exists";
			} else {
				ok 0, "$description $path: expected to exist but seems to be deleted";
			}
		} elsif ($expected_type) {
			ok 1, "$description $path: seems to exist";
		} else {
			ok 1, "$description $path: seems to be deleted";
		}
	}

	foreach my $path (keys %$expected) {
		ok 0, "$description $path: no event received";
	}
}

1;
