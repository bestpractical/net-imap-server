package Net::Server::IMAP::Command::Store;
use base qw/Net::Server::IMAP::Command/;

sub run {
    my $self = shift;

    return $self->bad_command("Login first") if $self->connection->is_unauth;
    return $self->bad_command("Select a mailbox first")
        unless $self->connection->is_selected;

    my $options = $self->options;
    my ( $messages, $what, $flags ) = split( /\s+/, $options, 3 );
    $flags =~ s/^\(//;
    $flags =~ s/\)$//;
    my @flags = split ' ', $flags;
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
