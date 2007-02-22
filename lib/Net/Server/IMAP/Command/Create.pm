package Net::Server::IMAP::Command::Create;
use base qw/Net::Server::IMAP::Command/;

sub run {
    my $self = shift;

    return $self->no_command("Permission denied");

    my ($name) = $self->parsed_options;
    my $mailbox = $self->connection->model->lookup($name);
    return $self->no_command("Mailbox already exists") if $mailbox;

    my $root = $self->connection->model->root;
    $self->connection->model->add_child( $root, name => $name );

    $self->ok_completed();
}

1;
