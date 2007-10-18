package Net::Server::IMAP;

use warnings;
use strict;

use base 'Class::Accessor';

use UNIVERSAL::require;
use Module::Refresh;    # for development
use Carp;
use IO::Select;
use IO::Socket;
use IO::Socket::SSL;

use Net::Server::IMAP::Mailbox;
use Net::Server::IMAP::Connection;

our $VERSION = '0.001';

__PACKAGE__->mk_accessors(
    qw/socket ssl_socket select connections port auth_class model_class ssl_port/);

sub new {
    my $class = shift;
    return $class->SUPER::new(
        {   port        => 8080,
            ssl_port    => 0,
            auth_class  => "Net::Server::IMAP::DefaultAuth",
            model_class => "Net::Server::IMAP::DefaultModel",
            @_,
            connections => {},
        }
    );
}

sub run {
    my $self = shift;

    my $lsn = IO::Socket::INET->new(
        Listen    => 1,
        LocalPort => $self->port,
        ReuseAddr => 1
    );
    if   ($@) { die "Listen on port " . $self->port . " failed: $@"; }
    else      { warn "Listening on " . $self->port . "\n" }
    $self->socket($lsn);
    $self->select( IO::Select->new($lsn) );

    my $ssl;
    if ($self->ssl_port) {
        $ssl = IO::Socket::SSL->new(
            Listen    => 1,
            LocalPort => $self->ssl_port,
            ReuseAddr => 1
        );
        if   ($@) { die "SSL Listen on port " . $self->ssl_port . " failed: $@"; }
        else      { warn "SSL Listening on " . $self->ssl_port . "\n" }
        $self->ssl_socket($ssl);
        $self->select->add($ssl);
    }

    while ( $self->select ) {
        while ( my @ready = $self->select->can_read ) {
            Module::Refresh->refresh;
            foreach my $fh (@ready) {
                if ( $fh == $lsn or (defined $ssl and $fh == $ssl)) {

                    # Create a new socket
                    my $new = $fh->accept;
                    # Accept can fail; if so, ignore the connection
                    $self->accept_connection($new) if $new;
                } else {

                    # Process socket
                    local $Net::Server::IMAP::Server = $self;
                    local $self->{connection} = $self->connections->{ $fh->fileno };
                    $self->connections->{ $fh->fileno }->handle_command;
                }
            }
        }
    }
}

DESTROY {
    my $self = shift;
    $_->close for grep { defined $_ } values %{ $self->connections };
    $self->socket->close if $self->socket;
}

sub connection {
    my $self = shift;
    return $self->{connection};
}

sub concurrent_connections {
    my $class = shift;
    my $self = ref $class ? $class : $Net::Server::IMAP::Server;
    my $selected = shift || $self->connection->selected;

    return () unless $selected;
    return grep {$_->is_auth and $_->is_selected
                 and $_->selected eq $selected} values %{$self->connections};
}

sub accept_connection {
    my $self   = shift;
    my $handle = shift;
    $self->select->add($handle);
    my $conn = Net::Server::IMAP::Connection->new(
        io_handle => $handle,
        server    => $self,
    );
    $self->connections->{ $handle->fileno } = $conn;
    return $conn;
}

sub capability {
    my $self = shift;
    my ($connection) = @_;

    return "IMAP4rev1 STARTTLS AUTH=PLAIN CHILDREN";
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

Net::Server::IMAP - [One line description of module's purpose here]


=head1 SYNOPSIS

    use Net::Server::IMAP;

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

Net::Server::IMAP requires no configuration files or environment variables.


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
C<bug-net-server-imap4@rt.cpan.org>, or through the web interface at
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
