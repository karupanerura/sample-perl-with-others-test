use strict;
use warnings;

use Test2::V0;
use Plack::Test;
use HTTP::Request;
use HTTP::Request::Common;
use HTTP::Response;

use Plack::Util;
use Starlet::Server;
use IO::Socket::INET;
use LWP::UserAgent;

sub do_test {
    my $callback = shift;
    if ($ENV{USE_GO_APP}) {
        $callback->(\&go_app_req);
    } else {
        test_psgi
            app => Plack::Util::load_psgi('./app.psgi'),
            client => $callback;
    }
}

my $internal_sock = IO::Socket::INET->new(
    Listen    => 128,
    LocalPort => $ENV{PERL_API_PORT},
    LocalAddr => '127.0.0.1',
    Proto     => 'tcp',
    ReuseAddr => 1,
) or die "failed to listen to port $ENV{PERL_API_PORT}:$!";

my $internal_app = Plack::Util::load_psgi('./internal.psgi');
my $internal_server = do {
    my @listens;
    $listens[$internal_sock->fileno] = { sock => $internal_sock };

    my $server = Starlet::Server->new(listens => \@listens, max_keepalive_reqs => 0);
    $server->setup_listener();
    $server;
};

package MyProtocol {
    use parent qw/LWP::Protocol::http/;

    sub socket_class { __PACKAGE__.'::Socket' }
};

package MyProtocol::Socket {
    use parent -norequire => qw/LWP::Protocol::http::Socket/;

    use IO::Select;

    sub read_response_headers {
        my $client_sock = shift;

        my $select = IO::Select->new();
        $select->add($internal_sock);
        $select->add($client_sock);

        my $timeout = ${*$client_sock}{io_socket_timeout} || undef;
        while (1) {
            my @readable = $select->can_read($timeout);
            if (@readable == 2) {
                $internal_server->accept_loop($internal_app, 1);
                last
            } elsif (@readable == 0) {
                next
            } elsif ($readable[0] == $internal_sock) {
                $internal_server->accept_loop($internal_app, 1);
            } elsif ($readable[0] == $client_sock) {
                last
            }
        }
        return $client_sock->SUPER::read_response_headers(@_);
    }
};

my $user_agent = LWP::UserAgent->new(
    timeout      => 10,
    max_redirect => 0,
);
$user_agent->add_handler(request_send => sub {
    my ($req, $ua, $handler) = @_;
    my $protocol = LWP::Protocol::create($req->uri->scheme, $ua);
    my $socket_type = $protocol->socket_type();
    if ($socket_type eq 'http') {
        bless $protocol, 'MyProtocol';
    } else {
        die "Unknown protocol for url @{[ $req->uri ]}";
    }

    return $protocol->request($req, undef, undef, undef, $ua->timeout);
});

my $base_uri = URI->new("http://127.0.0.1:@{[ $ENV{GO_APP_PORT} || 80 ]}/");

sub go_app_req {
    my $req = shift;
    my $uri2 = $base_uri->clone();
    $uri2->path_query($req->uri);

    my $req2 = $req->clone();
    $req2->uri($uri2);
    return $user_agent->request($req2);
}

do_test(sub {
    my $cb = shift;
    my $res = $cb->(GET '/');
    is $res->code, 200, '200 OK';
    is $res->content, "a:This is A\nb:This is B\n", 'content is OK';
});

done_testing;