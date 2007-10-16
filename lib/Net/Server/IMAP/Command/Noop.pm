package Net::Server::IMAP::Command::Noop;

use warnings;
use strict;

use base qw/Net::Server::IMAP::Command/;

sub validate {
    my $self = shift;

    my @options = $self->parsed_options;
    return $self->bad_command("Too many options") if @options;

    return 1;
}

sub run {
    my $self = shift;

    $self->connection->selected->poll if $self->connection->is_auth and $self->connection->is_selected;

    $self->ok_completed();
}

1;
