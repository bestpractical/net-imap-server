package Net::Server::IMAP::Command::Create;

use warnings;
use strict;

use base qw/Net::Server::IMAP::Command/;

sub validate {
    my $self = shift;

    # TODO: ???
    return $self->no_command("Permission denied");

    my @options = $self->parsed_options;
    return $self->bad_command("Not enough options") if @options < 1;
    return $self->bad_command("Too many options") if @options > 1;

    my($name) = @options;
    my $mailbox = $self->connection->model->lookup($name);
    return $self->no_command("Mailbox already exists") if $mailbox;

    return 1;
}

sub run {
    my $self = shift;

    my($name) = @options;

    my $root = $self->connection->model->root;
    $self->connection->model->add_child( $root, name => $name );

    $self->ok_completed();
}

1;
