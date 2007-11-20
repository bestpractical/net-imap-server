package Net::IMAP::Server::DefaultAuth;

use warnings;
use strict;

use base 'Class::Accessor';
__PACKAGE__->mk_accessors(qw(user));

sub provides_plain { return 1; }

sub auth_plain {
    my $self = shift;
    my ( $user, $pass ) = @_;
    $self->user($user);
    return 1;
}

sub provides_sasl {
    my $self = shift;
    my $type = shift;
    return $type eq "PLAIN" ? 1 : 0;
}

sub plain {
    my $self = shift;
    return sub {
        my $line = shift;
        return \"" unless $line;

        my ( $authz, $user, $pass ) = split /\x{0}/, $line, 3;
        return $self->auth_plain( $user, $pass );
    };
}

1;
