package Net::Server::IMAP::Command::Logout;

use warnings;
use strict;

use base qw/Net::Server::IMAP::Command/;

sub validate {
    my $self = shift;

    my @options = $self->parsed_options;
    return $self->bad_command("Too many options") if @options;

    return 1;
}

sub run {
    my $self = shift;

    $self->untagged_response('BYE Ok. I love you. Buhbye!');
    $self->ok_completed();
    $self->connection->close();
}

sub poll_after { 0 }

1;
