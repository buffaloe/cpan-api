
use strict;
use warnings;
use Test::More;
use MetaCPAN::Server::Test;

my %tests = (
    '/file'                             => 200,
    '/file/8yTixXQGpkbPsMBXKvDoJV4Qkg8' => 200,
    '/file/DOESNEXIST'                  => 404,
    '/file/DOES/Not/Exist.pm'           => 404,
    '/file/DOY/Moose-0.01/lib/Moose.pm' => 200
);

test_psgi app, sub {
    my $cb = shift;
    while ( my ( $k, $v ) = each %tests ) {
        ok( my $res = $cb->( GET $k), "GET $k" );
        is( $res->code, $v, "code $v" );
        is( $res->header( 'content-type' ),
            'application/json; charset=utf-8',
            'Content-type'
        );
        ok( my $json = eval { decode_json( $res->content ) }, 'valid json' );
        if ( $k eq '/file' ) {
            ok( $json->{hits}->{total}, 'got total count' );
        }
        elsif ( $v eq 200 ) {
            ok( $json->{name} eq 'Moose.pm', 'Moose.pm' );
        }
    }
};

done_testing;
