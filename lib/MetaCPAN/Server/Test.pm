package MetaCPAN::Server::Test;

# ABSTRACT: Test class for MetaCPAN::Web

use strict;
use warnings;
use Plack::Test;
use HTTP::Request::Common qw(POST GET DELETE);
use JSON::XS;
use Try::Tiny;
use Test::More;
use base 'Exporter';
our @EXPORT = qw(
    POST GET DELETE
    model
    test_psgi app
    encode_json decode_json
    try catch finally
);

BEGIN { $ENV{METACPAN_SERVER_CONFIG_LOCAL_SUFFIX} = 'testing'; }

$FindBin::RealBin .= '/some';
my $app = require MetaCPAN::Server;
ok( my $user = MetaCPAN::Server->model( 'User::Account' )->put(
        { access_token => [ { client => 'testing', token => 'testing' } ] }
    ),
    'prepare user'
);
ok( $user->add_identity( { name => 'pause', key => 'MO' } ),
    'add pause identity' );
ok( $user->put( { refresh => 1 } ), 'put user' );

ok( MetaCPAN::Server->model( 'User::Account' )->put(
        { access_token => [ { client => 'testing', token => 'bot' } ] },
        { refresh      => 1 }
    ),
    'put bot user'
);
sub app {$app}

require MetaCPAN::Model;

sub model {
    MetaCPAN::Model->new(
        es => ':' . ( $ENV{METACPAN_ES_TEST_PORT} ||= 9900 ) );
}

1;

=head1 ENVIRONMENTAL VARIABLES

Sets C<METACPAN_SERVER_CONFIG_LOCAL_SUFFIX> to C<testing>.

=head1 EXPORTS

=head2 GET

L<HTTP::Request::Common/GET>

=head2 test_psgi

L<Plack::Test/test_psgi>

=head2 app

Returns the L<MetaCPAN::Web> psgi app.
