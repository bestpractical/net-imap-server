package Net::Server::IMAP::Command::Expunge;

use warnings;
use strict;

use base qw/Net::Server::IMAP::Command/;

sub run {
    my $self = shift;

    return $self->bad_command("Log in first") if $self->connection->is_unauth;
    return $self->bad_command("Select a mailbox first")
        unless $self->connection->is_selected;

    my @ids = $self->connection->selected->expunge;

    $self->untagged_response( map {"$_ EXPUNGE"} @ids );

    $self->ok_completed();
}

1;
