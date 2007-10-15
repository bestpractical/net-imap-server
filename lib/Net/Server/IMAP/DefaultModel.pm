package Net::Server::IMAP::DefaultModel;

use warnings;
use strict;

use base 'Class::Accessor';
__PACKAGE__->mk_accessors(qw(auth root));

my %roots;

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    $self->init;
    return $self;
}

sub init {
    my $self = shift;
    my $user = $self->auth->user || 'default';

    if ( $roots{$user} ) {
        $self->root( $roots{$user} );
    } else {
        $self->root( $self->mailbox( name => "INBOX" ) );
        $self->root->add_child( name => $user );
        $roots{$user} = $self->root;
    }

    return $self;
}

sub seperator {
    return "/";
}

sub lookup {
    my $self  = shift;
    my $name  = shift;
    $name = "INBOX" if uc $name eq "INBOX";
    my @parts = split $self->seperator, $name;
    return undef unless @parts and shift @parts eq $self->root->name;
    my $part = $self->root;
    while (@parts) {
        return undef unless $part->children;
        my $find = shift @parts;
        my @match = grep { $_->name eq $find } @{ $part->children };
        return undef unless @match;
        $part = $match[0];
    }
    return $part;
}

sub mailbox {
    my $self = shift;
    return Net::Server::IMAP::Mailbox->new( { model => $self, @_ } );
}

1;
