package Net::IMAP::Server;

use warnings;
use strict;

use base qw/Net::Server::Coro Class::Accessor/;

use UNIVERSAL::require;
use Module::Refresh;    # for development
use Carp;
use Coro;

use Net::IMAP::Server::Mailbox;
use Net::IMAP::Server::Connection;

our $VERSION = '0.001';


=head1 NAME

Net::IMAP::Server - A single-threaded multiplexing IMAP server
implementation, using L<Net::Server::Coro>.

=head1 SYNOPSIS

  use Net::IMAP::Server;
  Net::IMAP::Server->new(
      port        => 193,
      ssl_port    => 993,
      auth_class  => "Your::Auth::Class",
      model_class => "Your::Model::Class",
  )->run;

=head1 DESCRIPTION

This model provides a complete implementation of the C<RFC 3501>
specification, along with several IMAP4rev1 extensions.  It provides
separation of the mailbox and message store from the client
interaction loop.

Note that, following RFC suggestions, login is not allowed except
under a either SSL or TLS.  Thus, you are required to have a F<certs/>
directory under the current working directory, containing files
F<server-cert.pem> and C<server-key.pem>.  Failure to do so will cause
the server to fail to start.

=head1 INTERFACE

The primary method of using this module is to supply your own model
and auth classes, which inherit from
L<Net::IMAP::Server::DefaultModel> and
L<Net::IMAP::Server::DefaultAuth>.  This allows you to back your
messages from arbitrary data sources, or provide your own
authorization backend.

=head1 METHODS

=cut

__PACKAGE__->mk_accessors(
    qw/connections port ssl_port auth_class model_class user group/);

=head2 new PARAMHASH

Creates a new IMAP server object.  This doesn't even bind to the
sockets; it merely initializes the object.  It will C<die> if it
cannot find the appropriate certificate files.  Valid arguments to
C<new> include:

=over

=item port

The port to bind to.  Defaults to port 4242.

=item ssl_port

The port to open an SSL listener on; by default, this is disabled, and
any true value enables it.

=item auth_class

The name of the class which implements authentication.  This must be a
subclass of L<Net::IMAP::Server::DefaultAuth>.

=item model_class

The name of the class which implements the model backend.  This must
be a subclass of L<Net::IMAP::Server::DefaultModel>.

=item user

The name or ID of the user that the server should run as; this
defaults to the current user.  Note that privileges are dropped after
binding to the port and reading the certificates, so escalated
privileges should not be needed.  Running as your C<nobody> user or
equivilent is suggested.

=back

=cut

sub new {
    my $class = shift;
    unless (-r "certs/server-cert.pem" and -r "certs/server-key.pem") {
        die "Can't read certs (certs/server-cert.pem and certs/server-key.pem)\n";
    }

    my $self = Class::Accessor::new($class,
        {   port        => 8080,
            ssl_port    => 0,
            auth_class  => "Net::IMAP::Server::DefaultAuth",
            model_class => "Net::IMAP::Server::DefaultModel",
            @_,
            connections => [],
        }
    );
    UNIVERSAL::require( $self->auth_class )
        or die "Can't require auth class: $@\n";
    $self->auth_class->isa("Net::IMAP::Server::DefaultAuth")
        or die "Auth class (@{[$self->auth_class]}) doesn't inherit from Net::IMAP::Server::DefaultAuth\n";

    UNIVERSAL::require( $self->model_class )
        or die "Can't require model class: $@\n";
    $self->model_class->isa("Net::IMAP::Server::DefaultModel")
        or die "Auth class (@{[$self->model_class]}) doesn't inherit from Net::IMAP::Server::DefaultModel\n";

    return $self;
}

sub run {
    my $self = shift;
    my @proto = qw/TCP/;
    my @port  = $self->port;
    if ($self->ssl_port) {
        push @proto, "SSL";
        push @port, $self->ssl_port;
    }
    local $Net::IMAP::Server::Server = $self;
    $self->SUPER::run(
        proto => \@proto,
        port  => \@port,
        user  => $self->user,
        group => $self->group,
    );
}

sub process_request {
    my $self = shift;
    my $handle = $self->{server}{client};
    my $conn = Net::IMAP::Server::Connection->new(
        io_handle => $handle,
        server    => $self,
    );
    $Coro::current->prio(-4);
    push @{$self->connections}, $conn;
    $conn->handle_lines;
}

DESTROY {
    my $self = shift;
    $_->close for grep { defined $_ } @{ $self->connections };
    $self->socket->close if $self->socket;
}

sub connection {
    my $self = shift;
    return $self->{connection};
}

sub auth {
    my $self = shift;
    return $self->{auth};
}

sub model {
    my $self = shift;
    return $self->{model};
}

sub concurrent_mailbox_connections {
    my $class = shift;
    my $self = ref $class ? $class : $Net::IMAP::Server::Server;
    my $selected = shift || $self->connection->selected;

    return () unless $selected;
    return grep {$_->is_auth and $_->is_selected
                 and $_->selected eq $selected} @{$self->connections};
}

sub concurrent_user_connections {
    my $class = shift;
    my $self = ref $class ? $class : $Net::IMAP::Server::Server;
    my $user = shift || $self->connection->auth->user;

    return () unless $user;
    return grep {$_->is_auth
                 and $_->auth->user eq $user} @{$self->connections};
}

sub capability {
    my $self = shift;
    return "IMAP4rev1 STARTTLS AUTH=PLAIN CHILDREN LITERAL+ UIDPLUS ID";
}

sub id {
    return (
            name => "Net-IMAP-Server",
            version => $Net::IMAP::Server::VERSION,
           );
}

1;    # Magic true value required at end of module
__END__



=head1 DEPENDENCIES

L<Coro>, L<Net::Server::Coro>

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-net-imap-server@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 AUTHOR

Alex Vandiver  C<< <alexmv@bestpractical.com> >>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2008, Best Practical Solutions, LLC.  All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
