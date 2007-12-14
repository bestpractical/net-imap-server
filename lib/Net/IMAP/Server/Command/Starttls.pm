package Net::IMAP::Server::Command::Starttls;

use warnings;
use strict;

use base qw/Net::IMAP::Server::Command/;

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
    my $handle = $self->connection->io_handle;
    $handle = tied(${$handle})->[0];
    IO::Socket::SSL->start_SSL( $handle,
        SSL_server => 1, );
    bless $handle, "Net::Server::Proto::SSL";
}

1;
