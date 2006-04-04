use warnings;
use strict;
package Net::Server::IMAP::Command::Capability;

use base qw/Net::Server::IMAP::Command/;


sub run {
    my $self = shift;
    $self->tagged_response('IMAP4rev1 AUTH=PLAIN');
    $self->ok_completed(alert => "This is an experimental server. Don't expect much");

}

1;
