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

__PACKAGE__->mk_accessors(
    qw/connections port ssl_port auth_class model_class/);

sub new {
    my $class = shift;
    return Class::Accessor::new($class,
        {   port        => 8080,
            ssl_port    => 0,
            auth_class  => "Net::IMAP::Server::DefaultAuth",
            model_class => "Net::IMAP::Server::DefaultModel",
            @_,
            connections => [],
        }
    );
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
    $self->SUPER::run(proto => \@proto, port => \@port);
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

=head1 NAME

Net::IMAP::Server - [One line description of module's purpose here]


=head1 SYNOPSIS

    use Net::IMAP::Server;

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.


=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE 

=for author to fill in:
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.


=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.

Net::IMAP::Server requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-net-imap-server@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

Jesse Vincent  C<< <jesse@bestpractical.com> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006, Best Practical Solutions, LLC.  All rights reserved.

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
