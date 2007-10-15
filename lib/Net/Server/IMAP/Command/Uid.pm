package Net::Server::IMAP::Command::Uid;
use base qw/Net::Server::IMAP::Command/;

sub validate {
    my $self = shift;

    return $self->bad_command("Select a mailbox first")
        unless $self->connection->is_selected;

    my @options = $self->parsed_options;
    return $self->bad_command("Not enough options") if @options < 1;

    return 1;
}

sub run {
    my $self = shift;

    my ($subcommand, @rest) = $self->parsed_options;
    $subcommand = lc $subcommand;
    if ($subcommand =~ /^(copy|fetch|store|search)$/i ) {
        $self->$subcommand(@rest);
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

    my ( $messages, $spec ) = @_;
    $spec = [$spec] unless ref $spec;
    push @{$spec}, "UID" unless grep {uc $_ eq "UID"} @{$spec};
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

    return $self->bad_command("Mailbox is read-only") if $self->connection->selected->read_only;

    my ( $messages, $what, @flags ) = @_;
    @flags = map {ref $_ ? @{$_} : $_} @flags;
    my @messages = $self->get_uids($messages);
    for my $m (@messages) {
        $m->store( $what => @flags );
        $self->untagged_response( $m->sequence
                . " FETCH "
                . $self->data_out( [ $m->fetch([qw/UID FLAGS/]) ] ) )
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
