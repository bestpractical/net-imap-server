package Net::Server::IMAP::Command::Uid;
use base qw/Net::Server::IMAP::Command/;

sub run {
    my $self = shift;

    return $self->bad_command("Select a mailbox first")
        unless $self->connection->is_selected;

    if ( $self->options =~ /^(copy|fetch|store|search)\s+(.*?)$/i ) {
        my $subcommand = lc $1;
        $self->$subcommand($2);
    } else {
        $self->log(
            $self->options . " wasn't understood by the 'UID' command" );
        $self->no_failed(
            alert => q{Your client sent a UID command we didn't understand} );
    }

}

sub get_uids {
    my $self = shift;
    my $str  = shift;

    my @ids;
    for ( split ',', $str ) {
        if (/^(\d+):(\d+)$/) {
            push @ids, $1 .. $2;
        } elsif (/^(\d+):\*$/) {
            push @ids, $1 .. $self->connection->selected->uidnext;
        } elsif (/^(\d+)$/) {
            push @ids, $1;
        }
    }
    return
        grep {defined} map { $self->connection->selected->uids->{$_} } @ids;
}

sub fetch {
    my $self = shift;
    my $args = shift;

    my ( $messages, $spec ) = split( /\s+/, $args, 2 );
    $spec =~ s/^(\()?/$1UID / unless $spec =~ /\bUID\b/;
    my @messages = $self->get_uids($messages);
    for my $m (@messages) {
        $self->untagged_response( $m->sequence
                . " FETCH "
                . $self->data_out( [ $m->fetch($spec) ] ) );
    }

    $self->ok_completed();
}

sub store {
    my $self = shift;
    my $args = shift;

    my ( $messages, $what, $flags ) = split( /\s+/, $args, 3 );
    $flags =~ s/^\(//;
    $flags =~ s/\)$//;
    my @flags = split ' ', $flags;
    my @messages = $self->get_uids($messages);
    for my $m (@messages) {
        $m->store( $what => @flags );
        $self->untagged_response( $m->sequence
                . " FETCH "
                . $self->data_out( [ $m->fetch("UID FLAGS") ] ) )
            unless $what =~ /\.SILENT$/i;
    }

    $self->ok_completed;
}

sub copy {
    my $self = shift;
    my $args = shift;
    $self->no_unimplemented();
    $self->ok_completed;

}

sub search {
    my $self = shift;
    my $args = shift;
    $self->no_unimplemented();
    $self->ok_completed;
}

1;
