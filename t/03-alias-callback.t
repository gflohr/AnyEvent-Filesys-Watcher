use strict;

use Test::More;
use Test::Exception;

use_ok 'AnyEvent::Filesys::Watcher';

my $instance;
lives_ok {
	$instance = AnyEvent::Filesys::Watcher->new(
		directories => ['.'],
		cb => sub {}
	);
}
ok $instance;

done_testing;
