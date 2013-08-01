use Test::More;
use strict;
use warnings;

use MetaCPAN::Server::Test;

my $model   = model();
my $idx     = $model->index( 'cpan' );
my $release = $idx->type( 'release' )->get(
    {   author => 'LOCAL',
        name   => 'File-Changes-1.0'
    }
);

is( $release->name,    'File-Changes-1.0', 'name ok' );
is( $release->author,  'LOCAL',            'author ok' );
is( $release->version, '1.0',              'version ok' );

{
    my @files
        = $idx->type( 'file' )
        ->filter(
        { and => [ { term => { distribution => 'File-Changes' } } ] } )->all;
    my ( $changes ) = grep { $_->{name} eq 'Changes' } @files;
    ok $changes, 'found Changes';
}

done_testing;
