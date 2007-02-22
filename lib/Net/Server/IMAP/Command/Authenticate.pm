package Net::Server::IMAP::Command::Authenticate;

use warnings;
use strict;

use MIME::Base64;
use base qw/Class::Accessor Net::Server::IMAP::Command/;

__PACKAGE__->mk_accessors(qw(sasl pending_auth));

sub run {
    my $self = shift;

    return $self->bad_command("Already logged in")
        unless $self->connection->is_unauth;

    my ($type) = $self->parsed_options;

    $self->server->auth_class->require || warn $@;
    my $auth = $self->server->auth_class->new;
    if ( $auth->provides_sasl( uc $type ) ) {
        $type = lc $type;
        $self->sasl( $auth->$type() );
        $self->pending_auth($auth);
        $self->connection->pending($self);
        $self->continue("");
    } else {
        $self->bad_command("Invalid login");
    }
}

sub continue {
    my $self = shift;
    my $line = shift;

    if ( not defined $line or $line =~ /^\*[\r\n]+$/ ) {
        $self->connection->pending(undef);
        $self->bad_command("Login cancelled");
        return;
    }

    $line = decode_base64($line);

    my $response = $self->sasl->($line);
    if ( ref $response ) {
        $self->out( "+ " . encode_base64($$response) . "\r\n" );
    } elsif ($response) {
        $self->connection->pending(undef);
        $self->connection->auth( $self->pending_auth );
        $self->ok_completed();
    } else {
        $self->connection->pending(undef);
        $self->bad_command("Invalid login");
    }
}

1;
