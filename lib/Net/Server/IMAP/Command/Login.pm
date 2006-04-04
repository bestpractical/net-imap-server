package Net::Server::IMAP::Command::Login;
use base qw/Net::Server::IMAP::Command/;

sub run {
    my $self = shift;
    $self->log("User attempted to log in with credentials: ".$self->options);
    $self->log("I'm a very trusting sort of server. We logged them in");
    $self->ok_completed();
}

1;
