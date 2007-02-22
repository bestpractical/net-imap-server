package Net::Server::IMAP::Command::Login;

use warnings;
use strict;

use base qw/Net::Server::IMAP::Command/;

sub run {
    my $self = shift;

    return $self->bad_command("Already logged in")
        unless $self->connection->is_unauth;

    $self->server->auth_class->require || warn $@;
    my $auth = $self->server->auth_class->new;
    if (    $auth->provides_plain
        and $auth->auth_plain( $self->parsed_options ) )
    {
        $self->connection->auth($auth);
        $self->ok_completed();
    } else {
        $self->bad_command("Invalid login");
    }
}

1;
