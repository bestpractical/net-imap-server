package Net::IMAP::Server::DefaultModel;

use warnings;
use strict;

use base 'Class::Accessor';
__PACKAGE__->mk_accessors(qw(auth root));

use Net::IMAP::Server::Mailbox;

my %roots;

=head1 NAME

Net::IMAP::Server::DefaultModel - Encapsulates per-connection
information about the layout of IMAP folders.

=head1 DESCRIPTION

This class represents an abstract model backend to the IMAP server; it
it meant to be overridden by server implementations.  Primarily,
subclasses are expected to override L</init> to set up their folder
structure.

=head1 METHODS

=head2 new

This class is created when the client has successfully authenticated
to the server.

=cut

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    $self->init;
    return $self;
}

=head2 init

Called when the class is instantiated, with no arguments.  Subclasses
should override this methtod to inspect the L</auth> object, and
determine what folders the user should have.  The primary purpose of
this method is to set L</root> to the top level of the mailbox tree.
The root is expected to contain a mailbox named C<INBOX>, which should
have L<Net::IMAP::Server::Mailbox/is_inbox> set.

=cut

sub init {
    my $self = shift;
    my $user = $self->auth->user || 'default';

    if ( $roots{$user} ) {
        $self->root( $roots{$user} );
    } else {
        $self->root( Net::IMAP::Server::Mailbox->new() )
            ->add_child( name => "INBOX", is_inbox => 1 )
            ->add_child( name => $user );
        $roots{$user} = $self->root;
    }

    return $self;
}

=head2 close

Called when this model's connection closes, for any reason.  By
default, does nothing.

=cut

sub close {
}

=head2 split PATH

Utility method which splits a given C<PATH> according to the mailbox
seperator, as determinded by the
L<Net::IMAP::Server::Mailbox/seperator> of the L</root>.

=cut

sub split {
    my $self = shift;
    return grep {length} split quotemeta $self->root->seperator, shift;
}

=head2 lookup PATH

Given a C<PATH>, returns the L<Net::IMAP::Server::Mailbox> for that
path, or undef if none matches.

=cut

sub lookup {
    my $self  = shift;
    my $name  = shift;
    my @parts = $self->split($name);
    my $part  = $self->root;
    return undef unless @parts;
    while (@parts) {
        return undef unless @{ $part->children };
        my $find = shift @parts;
        my @match
            = grep { $_->is_inbox ? uc $find eq "INBOX" : $_->name eq $find }
            @{ $part->children };
        return undef unless @match;
        $part = $match[0];
    }
    return $part;
}

1;
