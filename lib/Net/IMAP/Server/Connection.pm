package Net::IMAP::Server::Connection;

use warnings;
use strict;

use base 'Class::Accessor';

use Coro;

use Net::IMAP::Server::Command;

__PACKAGE__->mk_accessors(
    qw(server io_handle _selected selected_read_only model pending temporary_messages temporary_sequence_map previous_exists untagged_expunge untagged_fetch ignore_flags last_poll commands timer coro)
);

=head1 NAME

Net::IMAP::Server::Connection - Connection to a client

=head1 DESCRIPTION

Maintains all of the state for a client connection to the IMAP server.

=head1 METHODS

=head2 new

Creates a new connection; the server will take care of this step.

=cut

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(
        {   @_,
            state            => "unauth",
            untagged_expunge => [],
            untagged_fetch   => {},
            last_poll        => time,
            commands         => 0,
            coro             => $Coro::current,
        }
    );
    $self->update_timer;
    return $self;
}

=head2 server

Returns the L<Net::IMAP::Server> that this connection is on.

=head2 coro

Returns the L<Coro> process associated with this connection.  For
things interacting with this conneciton, it will probably be the
current coroutine, except for interactions coming from event loops.

=head2 io_handle

Returns the IO handle that can be used to read from or write to the
client.

=head2 model

Gets or sets the L<Net::IMAP::Server::DefaultModel> or descendant
associated with this connection.  Note that connections which have not
authenticated yet do not have a model.

=head2 auth

Gets or sets the L<Net::IMAP::Server::DefaultAuth> or descendant
associated with this connection.  Note that connections which have not
authenticated yet do not have an auth object.

=cut

sub auth {
    my $self = shift;
    if (@_) {
        $self->{auth} = shift;
        $self->server->model_class->require || warn $@;
        $self->update_timer;
        $self->model(
            $self->server->model_class->new( { auth => $self->{auth} } ) );
    }
    return $self->{auth};
}

=head2 selected [MAILBOX]

Gets or sets the currently selected mailbox for this connection.  This
may trigger the sending of untagged notifications to the client.

=cut

sub selected {
    my $self = shift;
    if ( @_ and $self->selected ) {
        unless ( $_[0] and $self->selected eq $_[0] ) {
            $self->send_untagged;
            $self->selected->close;
        }
        $self->selected_read_only(0);
    }
    return $self->_selected(@_);
}

=head2 greeting

Sends out a one-line untagged greeting to the client.

=cut

sub greeting {
    my $self = shift;
    $self->untagged_response('OK IMAP4rev1 Server');
}

=head2 handle_lines

The main line handling loop.  Since we are using L<Coro>, this cedes
to other coroutines whenever we block, given them a chance to run.  We
additionally cede after handling every command.

=cut

sub handle_lines {
    my $self = shift;
    $self->coro->prio(-4);

    local $self->server->{connection} = $self;

    eval {
        $self->greeting;
        while ( $self->io_handle and $_ = $self->io_handle->getline() ) {
            $self->server->{connection} = $self;
            $self->handle_command($_);
            $self->commands( $self->commands + 1 );
            if (    $self->is_unauth
                and $self->server->unauth_commands
                and $self->commands >= $self->server->unauth_commands )
            {
                $self->out(
                    "* BYE Don't noodle around so much before logging in!");
                $self->close;
                last;
            }
            $self->update_timer;
            cede;
        }

        $self->log(
            "-(@{[$self]},@{[$self->auth ? $self->auth->user : '???']},@{[$self->is_selected ? $self->selected->full_path : 'unselected']}): Connection closed by remote host"
        );
        $self->close;
    };
    my $err = $@;
    warn $err
        if $err and not( $err eq "Error printing\n" or $err eq "Timeout\n" );
}

=head2 update_timer

Updates the inactivity timer.

=cut

sub update_timer {
    my $self = shift;
    $self->timer->stop if $self->timer;
    $self->timer(undef);
    my $timeout = sub {
        eval { $self->out("* BYE Idle timeout; I fell asleep."); };
        $self->coro->throw("Timeout\n");
        $self->coro->ready;
    };
    if ( $self->is_unauth and $self->server->unauth_idle ) {
        $self->timer( EV::timer $self->server->unauth_idle, 0, $timeout );
    } elsif ( $self->server->auth_idle ) {
        $self->timer( EV::timer $self->server->auth_idle, 0, $timeout );
    }
}

=head2 timer [EV watcher]

Returns the L<EV> watcher in charge of the inactivity timer.

=head2 handle_command

Handles a single line from the client.  This is not quite the same as
handling a command, because of client literals and continuation
commands.

=cut

sub handle_command {
    my $self    = shift;
    my $content = shift;

    $self->log(
        "C(@{[$self]},@{[$self->auth ? $self->auth->user : '???']},@{[$self->is_selected ? $self->selected->full_path : 'unselected']}): $content"
    );

    if ( $self->pending ) {
        $self->pending->($content);
        return;
    }

    my ( $id, $cmd, $options ) = $self->parse_command($content);
    return unless defined $id;

    my $cmd_class = "Net::IMAP::Server::Command::$cmd";
    $cmd_class->require() || warn $@;
    unless ( $cmd_class->can('run') ) {
        $cmd_class = "Net::IMAP::Server::Command";
    }
    my $handler = $cmd_class->new(
        {   server      => $self->server,
            connection  => $self,
            options_str => $options,
            command_id  => $id,
            command     => $cmd
        }
    );
    return if $handler->has_literal;

    eval { $handler->run() if $handler->validate; };
    if ( my $error = $@ ) {
        $handler->no_command("Server error");
        $self->log($error);
    }
}

=head2 pending

If a connection has pending state, contains the callback that will
receive the next line of input.

=cut

=head2 close

Shuts down this connection, also closing the model and mailboxes.

=cut

sub close {
    my $self = shift;
    $self->server->connections(
        [ grep { $_ ne $self } @{ $self->server->connections } ] );
    if ( $self->io_handle ) {
        $self->io_handle->close;
        $self->io_handle(undef);
    }
    $self->timer->stop     if $self->timer;
    $self->selected->close if $self->selected;
    $self->model->close    if $self->model;
}

=head2 parse_command LINE

Parses the line into the C<tag>, C<ommand>, and C<options>.  Returns
undef if parsing fails for some reason.

=cut

sub parse_command {
    my $self = shift;
    my $line = shift;
    $line =~ s/[\r\n]+$//;
    unless ( $line =~ /^([^\(\)\{ \*\%"\\\+}]+)\s+(\w+)(?:\s+(.+?))?$/ ) {
        if ( $line !~ /^([^\(\)\{ \*\%"\\\+}]+)\s+/ ) {
            $self->out("* BAD Invalid tag");
        } else {
            $self->out("* BAD Null command ('$line')");
        }
        return undef;
    }

    my $id   = $1;
    my $cmd  = $2;
    my $args = $3 || '';
    $cmd = ucfirst( lc($cmd) );
    return ( $id, $cmd, $args );
}

=head2 is_unauth

Returns true if the connection is unauthenticated.

=cut

sub is_unauth {
    my $self = shift;
    return not defined $self->auth;
}

=head2 is_auth

Returns true if the connection is authenticated.

=cut

sub is_auth {
    my $self = shift;
    return defined $self->auth;
}

=head2 is_selected

Returns true if the connection has selected a mailbox.

=cut

sub is_selected {
    my $self = shift;
    return defined $self->selected;
}

=head2 is_encrypted

Returns true if the connection is protected by SSL or TLS.

=cut

sub is_encrypted {
    my $self   = shift;
    return $self->io_handle->is_ssl;
}

=head2 poll

Polls the currently selected mailbox, and resets the poll timer.

=cut

sub poll {
    my $self = shift;
    $self->selected->poll;
    $self->last_poll(time);
}

=head2 force_poll

Forces a poll of the selected mailbox the next chance we get.

=cut

sub force_poll {
    my $self = shift;
    $self->last_poll(0);
}

=head2 last_poll

Gets or sets the last time the selected mailbox was polled, in seconds
since the epoch.

=cut

=head2 send_untagged

Sends any untagged updates about the current mailbox to the client.

=cut

sub send_untagged {
    my $self = shift;
    my %args = (
        expunged => 1,
        @_
    );
    return unless $self->is_auth and $self->is_selected;

    if ( time >= $self->last_poll + $self->server->poll_every ) {

        # When we poll, the things that we find should affect this
        # connection as well; hence, the local to be "connection-less"
        local $Net::IMAP::Server::Server->{connection};
        $self->poll;
    }

    for my $s ( keys %{ $self->untagged_fetch } ) {
        my ($m) = $self->get_messages($s);
        $self->untagged_response(
                  $s 
                . " FETCH "
                . Net::IMAP::Server::Command->data_out(
                [ $m->fetch( [ keys %{ $self->untagged_fetch->{$s} } ] ) ]
                )
        );
    }
    $self->untagged_fetch( {} );

    if ( $args{expunged} ) {

# Make sure that they know of at least the existance of what's being expunged.
        my $max = 0;
        $max = $max < $_ ? $_ : $max for @{ $self->untagged_expunge };
        $self->untagged_response("$max EXISTS")
            if $max > $self->previous_exists;

        # Send the expnges, clear out the temporary message store
        $self->previous_exists(
            $self->previous_exists - @{ $self->untagged_expunge } );
        $self->untagged_response( map {"$_ EXPUNGE"}
                @{ $self->untagged_expunge } );
        $self->untagged_expunge( [] );
        $self->temporary_messages(undef);
    }

    # Let them know of more EXISTS
    my $expected = $self->previous_exists;
    my $now = @{ $self->temporary_messages || $self->selected->messages };
    $self->untagged_response( $now . ' EXISTS' ) if $expected != $now;
    $self->previous_exists($now);
}

=head2 get_messages STR

Parses and returns messages fitting the given sequence range.  This is
on the connection and not the mailbox because messages have
connection-dependent sequence numbers.

=cut

sub get_messages {
    my $self = shift;
    my $str  = shift;

    my $messages = $self->temporary_messages || $self->selected->messages;

    my %ids;
    for ( split ',', $str ) {
        if (/^(\d+):(\d+)$/) {
            $ids{$_}++ for $2 > $1 ? $1 .. $2 : $2 .. $1;
        } elsif ( /^(\d+):\*$/ or /^\*:(\d+)$/ ) {
            $ids{$_}++ for @{$messages} + 0, $1 .. @{$messages} + 0;
        } elsif (/^(\d+)$/) {
            $ids{$1}++;
        } elsif (/^\*$/) {
            $ids{ @{$messages} + 0 }++;
        }
    }
    return grep {defined}
        map { $messages->[ $_ - 1 ] } sort { $a <=> $b } keys %ids;
}

=head2 sequence MESSAGE

Returns the sequence number for the given message.

=cut

sub sequence {
    my $self    = shift;
    my $message = shift;

    return $message->sequence unless $self->temporary_messages;
    return $self->temporary_sequence_map->{$message};
}

=head2 capability

Returns the current capability list for this connection, as a string.
Connections not under TLS or SSL always have the C<LOGINDISABLED>
capability, and no authentication capabilities.  The
L<Net::IMAP::Server/auth_class>'s
L<Net::IMAP::Server::DefaultAuth/sasl_provides> method is used to list
known C<AUTH=> types.

=cut

sub capability {
    my $self = shift;

    my $base = $self->server->capability;
    if ( $self->is_encrypted ) {
        my $auth = $self->auth || $self->server->auth_class->new;
        $base = join( " ",
            grep { $_ ne "STARTTLS" } split( ' ', $base ),
            map {"AUTH=$_"} $auth->sasl_provides );
    } else {
        $base = "$base LOGINDISABLED";
    }

    return $base;
}

=head2 log MESSAGE

Logs the message to standard error, using C<warn>.

=cut

sub log {
    my $self = shift;
    my $msg  = shift;
    chomp($msg);
    warn $msg . "\n";
}

=head2 untagged_response STRING

Sends an untagged response to the client; a newline ia automatically
appended.

=cut

sub untagged_response {
    my $self = shift;
    $self->out("* $_") for grep defined, @_;
}

=head2 out STRING

Sends the mesage to the client.  If the client's connection has
dropped, or the send fails for whatever reason, L</close> the
connection and then die, which is caught by L</handle_lines>.

=cut

sub out {
    my $self = shift;
    my $msg  = shift;
    if ( $self->io_handle and $self->io_handle->peerport ) {
        if ( $self->io_handle->print( $msg . "\r\n" ) ) {
            $self->log(
                "S(@{[$self]},@{[$self->auth ? $self->auth->user : '???']},@{[$self->is_selected ? $self->selected->full_path : 'unselected']}): $msg"
            );
        } else {
            $self->close;
            die "Error printing\n";
        }
    } else {
        $self->close;
        die "Error printing\n";
    }
    warn "Connection is no longer me!" if $self->server->connection ne $self;
    $self->server->{connection} = $self;
}

1;
