use strict;
use warnings;

use lib 'lib';
use MyApp;

sub {
    my $env = shift;

    if ($env->{PATH_INFO} eq '/internal/a') {
        my $ret_a = MyApp->call_a();
        return [200, [], [$ret_a]];
    } elsif ($env->{PATH_INFO} eq '/internal/b') {
        my $ret_b = MyApp->call_b();
        return [200, [], [$ret_b]];
    } else {
        return [404, [], ['Not found']]
    }
};