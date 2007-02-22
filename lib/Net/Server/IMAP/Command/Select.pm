package Net::Server::IMAP::Command::Select;

use warnings;
use strict;

use base qw/Net::Server::IMAP::Command/;

sub run {
    my $self = shift;

    return $self->bad_command("Log in first") if $self->connection->is_unauth;

    my $mailbox = $self->connection->model->lookup( $self->parsed_options );
    return $self->no_command("Mailbox does not exist") unless $mailbox;

    $mailbox->force_read_only(1) if $self->command eq "Examine";
    $self->connection->selected($mailbox);

    $self->untagged_response(
        'FLAGS (' . join( ' ', $mailbox->flags ) . ')' );
    $self->untagged_response( $mailbox->exists . ' EXISTS' );
    $self->untagged_response( $mailbox->recent . ' RECENT' );

    my $unseen = $mailbox->unseen;
    $self->untagged_response("OK [UNSEEN $unseen]") if defined $unseen;

    my $uidvalidity = $mailbox->uidvalidity;
    $self->untagged_response("OK [UIDVALIDITY $uidvalidity]")
        if defined $uidvalidity;

    my $uidnext = $mailbox->uidnext;
    $self->untagged_response("OK [UIDNEXT $uidnext]") if defined $uidnext;

    my $permanentflags = $mailbox->permanentflags;
    $self->untagged_response( "OK [PERMANENTFLAGS ("
            . join( ' ', $mailbox->permanentflags )
            . ')]' );

    if ( $mailbox->read_only ) {
        $self->ok_command("[READ-ONLY] Completed");
    } else {
        $self->ok_command("[READ-WRITE] Completed");
    }
}

1;
