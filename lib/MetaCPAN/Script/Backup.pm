package MetaCPAN::Script::Backup;

use Moose;
with 'MooseX::Getopt';
use Log::Contextual qw( :log :dlog );
with 'MetaCPAN::Role::Common';
use MooseX::Types::Path::Class qw(:all);
use IO::Zlib ();
use JSON::XS;
use DateTime;

has type => (
    is            => 'ro',
    isa           => 'Str',
    documentation => 'ES type do backup, optional'
);

has size => (
    is            => 'ro',
    isa           => 'Int',
    default       => 1000,
    documentation => 'Size of documents to fetch at once, defaults to 1000'
);

has purge => (
    is            => 'ro',
    isa           => 'Bool',
    documentation => 'Purge old backups'
);

has dry_run => (
    is            => 'ro',
    isa           => 'Bool',
    documentation => 'Don\'t actually purge old backups'
);

has restore => (
    is            => 'ro',
    isa           => File,
    coerce        => 1,
    documentation => 'Restore a backup',
);

sub run {
    my $self = shift;
    return $self->run_purge   if ( $self->purge );
    return $self->run_restore if ( $self->restore );
    my $es = $self->es;
    $self->index->refresh;
    my $filename = join( "-",
        DateTime->now->strftime( "%F" ),
        grep {defined} $self->index->name,
        $self->type );
    my $file
        = $self->home->subdir( qw(var backup) )->file( "$filename.json.gz" );
    $file->dir->mkpath unless ( -e $file->dir );
    my $fh = IO::Zlib->new( "$file", "wb4" );
    my $scroll = $es->scrolled_search(
        index => $self->index->name,
        $self->type ? ( type => $self->type ) : (),
        size        => $self->size,
        search_type => 'scan',
        fields      => [qw(_parent _source)],
        scroll      => '1m',
    );
    log_info { "Backing up ", $scroll->total, " documents" };

    while ( my $result = $scroll->next ) {
        print $fh encode_json( $result ), $/;
    }
    close $fh;
    log_info {"done"};
}

sub run_restore {
    my $self = shift;
    return log_fatal { $self->restore, " doesn't exist" }
    unless ( -e $self->restore );
    log_info { "Restoring from ", $self->restore };
    my @bulk;
    my $es = $self->es;
    my $fh = IO::Zlib->new( $self->restore->stringify, "rb" );
    while ( my $line = $fh->readline ) {
        my $obj    = decode_json( $line );
        my $parent = $obj->{fields}->{_parent};
        push(
            @bulk,
            {   id => $obj->{_id},
                $parent ? ( parent => $parent ) : (),
                index => $obj->{_index},
                type  => $obj->{_type},
                data  => $obj->{_source},
            }
        );
        if ( @bulk > 100 ) {
            $es->bulk_index( \@bulk );
            @bulk = ();
        }
    }
    $es->bulk_index( \@bulk );
    log_info {"done"};

}

sub run_purge {
    my $self = shift;
    my $now  = DateTime->now;
    $self->home->subdir( qw(var backup) )->recurse(
        callback => sub {
            my $file = shift;
            return if ( $file->is_dir );
            my $mtime = DateTime->from_epoch( epoch => $file->stat->mtime );

            # keep a daily backup for one week
            return
                if ( $mtime > $now->clone->subtract( days => 7 ) );

            # after that keep weekly backups
            if ( $mtime->clone->truncate( to => 'week' )
                != $mtime->clone->truncate( to => 'day' ) )
            {
                log_info        {"Removing old backup $file"};
                return log_info {"Not (dry run)"}
                if ( $self->dry_run );
                $file->remove;
            }
        }
    );
}

1;

__END__

=head1 NAME

MetaCPAN::Script::Backup - Backup indices and types

=head1 SYNOPSIS

 $ bin/metacpan backup --index user --type account
 
 $ bin/metacpan backup --purge
 
=head1 DESCRIPTION

Creates C<.json.gz> files in C<var/backup>. These files contain
one record per line.

=head2 purge

Purges old backups. Backups from the current week are kept.
