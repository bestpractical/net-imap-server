package Net::Server::IMAP::Command::Starttls;

use warnings;
use strict;

use base qw/Net::Server::IMAP::Command/;

use IO::Socket::SSL;

sub validate {
    my $self = shift;

    return $self->bad_command("Already logged in")
        unless $self->connection->is_unauth;

    my @options = $self->parsed_options;
    return $self->bad_command("Too many options") if @options;

    return $self->no_command("STARTTLS is disabled")
      unless $self->connection->capability =~ /\bSTARTTLS\b/;

    return 1;
}

sub run {
    my $self = shift;

    $self->ok_completed;
    IO::Socket::SSL->start_SSL( $self->connection->io_handle,
        SSL_server => 1, );
}

1;
