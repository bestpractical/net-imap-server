package Net::Server::IMAP::Command::Store;

use warnings;
use strict;

use base qw/Net::Server::IMAP::Command/;

sub validate {
    my $self = shift;

    return $self->bad_command("Login first") if $self->connection->is_unauth;
    return $self->bad_command("Select a mailbox first")
        unless $self->connection->is_selected;

    return $self->bad_command("Mailbox is read-only") if $self->connection->selected->read_only;

    my @options = $self->parsed_options;
    return $self->bad_command("Not enough options") if @options < 3;
    return $self->bad_command("Too many options") if @options > 3;

    return 1;
}

sub run {
    my $self = shift;

    my ( $messages, $what, @flags ) = $self->parsed_options;
    @flags = map {ref $_ ? @{$_} : $_} @flags;
    my @messages = $self->connection->selected->get_messages($messages);
    for my $m (@messages) {
        $m->store( $what => @flags );
        $self->untagged_response( $m->sequence
                . " FETCH "
                . $self->data_out( [ $m->fetch("FLAGS") ] ) )
            unless $what =~ /\.SILENT$/i;
    }

    $self->ok_completed();
}

1;
