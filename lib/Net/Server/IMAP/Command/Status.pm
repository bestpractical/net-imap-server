package Net::Server::IMAP::Command::Status;

use warnings;
use strict;

use base qw/Net::Server::IMAP::Command/;

sub run {
    my $self = shift;

    return $self->bad_command("Log in first") if $self->connection->is_unauth;

    return $self->bad_command("Bad arguments to STATUS")
        unless $self->options =~ /(\w+)\s+\((.*?)\)/;
    my ( $name, @options ) = ( $1, split ' ', $2 );

    my $mailbox = $self->server->mailbox( $self->connection, $name );
    return $self->no_command("Mailbox does not exist") unless $mailbox;

    my %items;
    $items{ uc $_ } = undef for @options;

    for my $i ( keys %items ) {
        if ( $i eq "MESSAGES" ) {
            $items{$i} = $mailbox->exists;
        } elsif ( $i eq "RECENT" ) {
            $items{$i} = $mailbox->recent;
        } elsif ( $i eq "UNSEEN" ) {
            my $unseen = $mailbox->unseen;
            if ( defined $unseen ) {
                $items{$i} = $unseen;
            } else {
                delete $items{$i};
            }
        } elsif ( $i eq "UIDVALIDITY" ) {
            my $uidvalidity = $mailbox->uidvalidity;
            if ( defined $uidvalidity ) {
                $items{$i} = $uidvalidity;
            } else {
                delete $items{$i};
            }
        } elsif ( $i eq "UIDNEXT" ) {
            my $uidnext = $mailbox->uidnext;
            if ( defined $uidnext ) {
                $items{$i} = $uidnext;
            } else {
                delete $items{$i};
            }
        } else {
            delete $items{$i};
        }
    }
    $self->untagged_response( "STATUS $name (" . join( ' ', %items ) . ")" );
    $self->ok_completed;
}

1;
