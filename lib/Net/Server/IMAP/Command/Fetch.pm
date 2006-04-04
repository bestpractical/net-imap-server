package Net::Server::IMAP::Command::Fetch;
use base qw/Net::Server::IMAP::Command/;

sub run {
    my $self = shift;
    warn "The client asked for messages, but we have none to give";
    $self->ok_completed();
}

1;
