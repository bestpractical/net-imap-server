package Net::Server::IMAP::Command::Uid;
use base qw/Net::Server::IMAP::Command/;


sub run {
    my $self = shift;
    warn "My options are ".$self->options()."\n";
    if ($self->options =~/^(copy|fetch|store|search)\s+(.*?)$/i ) {
        $self->command($self->command." ".uc($1));
        $self->$1($2);

    } else {
        $self->log($self->options." wasn't understood by the 'UID' command");
        $self->no_failed(alert => q{Your client sent a UID command we didn't understand});
    }


}

sub fetch {
    my $self = shift;
    my $args = shift;
    for(1..12) {
    $self->untagged_response("$_ (FLAGS () UID $_)");
    }
        $self->ok_completed;
}

sub store {
    my $self = shift;
    my $args = shift;
        $self->no_unimplemented();
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
