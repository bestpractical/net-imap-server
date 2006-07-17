package Net::Server::IMAP::Command::Noop;
use base qw/Net::Server::IMAP::Command/;

sub run {
    my $self = shift;
    $self->ok_completed();
}

1;
