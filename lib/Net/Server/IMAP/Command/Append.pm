package Net::Server::IMAP::Command::Append;

use warnings;
use strict;

use base qw/Net::Server::IMAP::Command/;

sub validate {
    my $self = shift;

    return $self->bad_command("Log in first") if $self->connection->is_unauth;

    my @options = $self->parsed_options;
    return $self->bad_command("Not enough options") if @options < 2;
    return $self->bad_command("Too many options") if @options > 4;

    my $mailbox = $self->connection->model->lookup( $options[0] );
    return $self->no_command("Mailbox does not exist") unless $mailbox;

    return 1;
}

sub run {
    my $self = shift;

    my @options = $self->parsed_options;

    my $mailbox = $self->connection->model->lookup( shift @options );
    # XXX TODO: Deal with flags, internaldate
    if ($mailbox->append(pop @options)) {
        $self->connection->previous_exists( $self->connection->previous_exists + 1 )
          if $mailbox eq $self->connection->selected;
        $self->ok_completed();
    } else {
        $self->no_command("Permission denied");
    }
}

1;
