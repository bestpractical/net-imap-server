package Net::Server::IMAP::Command::Lsub;

use warnings;
use strict;

use base qw/Net::Server::IMAP::Command::List/;

sub traverse {
    my $self = shift;
    my $node = shift;

    return unless $node->subscribed;
    $self->SUPER::traverse( $node, @_ );
}

1;
