# This is intentionally not Net::IMAP::Server::Command::Error, so that
# it does not pollute the client command namespace
package Net::IMAP::Server::Error;

use warnings;
use strict;

use base qw/Net::IMAP::Server::Command/;

sub run {
    my $self = shift;

    $self->no_command("Server error");
}

1;
