use warnings;
use strict;

package Net::Server::IMAP::Command::Authenticate;
use base qw/Net::Server::IMAP::Command/;


sub run {
    my $self = shift;
    $self->ok_completed();
}

1;
