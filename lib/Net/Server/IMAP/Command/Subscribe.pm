package Net::Server::IMAP::Command::Subscribe;

use warnings;
use strict;

use base qw/Net::Server::IMAP::Command/;

sub validate {
    my $self = shift;

    my @options = $self->parsed_options;
    return $self->bad_command("Not enough options") if @options < 1;
    return $self->bad_command("Too many options") if @options > 1;

    my $mailbox = $self->connection->model->lookup( @options );
    return $self->no_command("Mailbox does not exist") unless $mailbox;

    return 1;
}

sub run {
    my $self = shift;

    $self->ok_completed();
}

1;
