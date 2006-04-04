package Net::Server::IMAP::Command::Logout;

use base qw/Net::Server::IMAP::Command/;

sub run {
    my $self = shift;
    $self->untagged_response('BYE Ok. I love you. Buhbye!');
    $self->ok_completed();
    $self->io_handle->close();
}

1;
