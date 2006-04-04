package Net::Server::IMAP::Command::Uid;
use base qw/Net::Server::IMAP::Command/;


sub run {
    my $self = shift;
    warn "My options are ".$self->options()."\n";
    if ($self->options =~/^(copy|fetch|store)\s+(.*?)i/i ) {
        # somehow do the fetch, store or copy
        $self->ok_completed;

    } elsif ($self->options =~/^search\s+(.*?)$/i) {
        $self->ok_completed;
    } else {
        $self->ok_completed(alert => 'hmm');
    }


}

1;
