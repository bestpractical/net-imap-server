package Net::Server::IMAP::Command::Status;

use warnings;
use strict;

use base qw/Net::Server::IMAP::Command/;

sub validate {
    my $self = shift;

    return $self->bad_command("Log in first") if $self->connection->is_unauth;

    my @options = $self->parsed_options;
    return $self->bad_command("Not enough options") if @options < 2;
    return $self->bad_command("Too many options") if @options > 2;

    my ( $name, $flags ) = @options;
    return $self->bad_command("Wrong second option") unless ref $flags;

    my $mailbox = $self->connection->model->lookup( $name );
    return $self->no_command("Mailbox does not exist") unless $mailbox;
    return $self->no_command("Mailbox is not selectable") unless $mailbox->selectable;

    return 1;
}

sub run {
    my $self = shift;

    my ( $name, $flags ) = $self->parsed_options;
    my $mailbox = $self->connection->model->lookup( $self->connection, $name );
    $mailbox->poll;

    my %items;
    $items{ uc $_ } = undef for @{$flags};

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
