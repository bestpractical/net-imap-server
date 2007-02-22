package Net::Server::IMAP::Command::Capability;

use warnings;
use strict;

use base qw/Net::Server::IMAP::Command/;

sub run {
    my $self = shift;
    $self->tagged_response( $self->server->capability );
    $self->ok_completed;
}

1;
