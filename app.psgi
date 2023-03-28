use strict;
use warnings;

use lib 'lib';
use MyApp;

sub {
    my $env = shift;

    my $ret_a = MyApp->call_a();
    my $ret_b = MyApp->call_b();
    return [200, [], ["a:$ret_a\nb:$ret_b\n"]];
};