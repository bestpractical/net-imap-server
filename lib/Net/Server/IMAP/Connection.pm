package Net::Server::IMAP::Connection;

use warnings;
use strict;

use base 'Class::Accessor';

use Net::Server::IMAP::Command;

__PACKAGE__->mk_accessors(qw(server io_handle _selected selected_read_only model pending temporary_messages temporary_sequence_map previous_exists untagged_expunge untagged_fetch ignore_flags));

sub new {
    my $class = shift;
    my $self = $class->SUPER::new( { @_, state => "unauth", untagged_expunge => [], untagged_fetch => {} } );
    $self->greeting;
    return $self;
}

sub greeting {
    my $self = shift;
    $self->out( '* OK IMAP4rev1 Server' . "\r\n" );
}

sub handle_lines {
    my $self    = shift;
    my $i = 0;
    ++$i and $self->handle_command($_) while $_ = $self->io_handle->getline();

    if ( not $i ) {
        $self->log("Connection closed by remote host");
        $self->close;
        return;
    }

}

sub handle_command {
    my $self = shift;
    my $content = shift;

    local $self->server->{connection} = $self;
    local $self->server->{model} = $self->model;
    local $self->server->{auth} = $self->auth;

    $self->log("C(@{[$self->io_handle->peerport]},@{[$self->auth ? $self->auth->user : '???']},@{[$self->is_selected ? $self->selected->full_path : 'unselected']}): $content");

    if ( $self->pending ) {
        $self->pending->($content);
        return;
    }

    my ( $id, $cmd, $options ) = $self->parse_command($content);
    return unless defined $id;

    my $cmd_class = "Net::Server::IMAP::Command::$cmd";
    $cmd_class->require() || warn $@;
    unless ( $cmd_class->can('run') ) {
        $cmd_class = "Net::Server::IMAP::Command";
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

    eval {
        $handler->run() if $handler->validate;
    };
    if (my $error = $@) {
        $handler->no_command("Server error");
        $self->log($error);
    }
}

sub close {
    my $self = shift;
    delete $self->server->connections->{ $self->io_handle->fileno };
    $self->server->select->remove( $self->io_handle );
    $self->io_handle->close;
    $self->model->close if $self->model;
}

sub parse_command {
    my $self = shift;
    my $line = shift;
    $line =~ s/[\r\n]+$//;
    unless ( $line =~ /^([^\(\)\{ \*\%"\\\+}]+)\s+(\w+)(?:\s+(.+?))?$/ ) {
        if ( $line !~ /^([^\(\)\{ \*\%"\\\+]+)\s+/ ) {
            $self->out("* BAD Invalid tag\r\n");
        } else {
            $self->out("* BAD Null command ('$line')\r\n");
        }
        return undef;
    }

    my $id   = $1;
    my $cmd  = $2;
    my $args = $3 || '';
    $cmd = ucfirst( lc($cmd) );
    return ( $id, $cmd, $args );
}

sub is_unauth {
    my $self = shift;
    return not defined $self->auth;
}

sub is_auth {
    my $self = shift;
    return defined $self->auth;
}

sub is_selected {
    my $self = shift;
    return defined $self->selected;
}

sub is_encrypted {
    my $self = shift;
    return $self->io_handle->isa("IO::Socket::SSL");
}

sub auth {
    my $self = shift;
    if (@_) {
        $self->{auth} = shift;
        $self->server->{auth} = $self->{auth};
        $self->server->model_class->require || warn $@;
        $self->model(
            $self->server->model_class->new( { auth => $self->{auth} } ) );
    }
    return $self->{auth};
}

sub selected {
    my $self = shift;
    $self->send_untagged if @_ and $self->selected;
    $self->selected_read_only(0) if @_ and $self->selected;
    return $self->_selected(@_);
}

sub untagged_response {
    my $self = shift;
    while ( my $message = shift ) {
        next unless $message;
        $self->out( "* " . $message . "\r\n" );
    }
}

sub send_untagged {
    my $self = shift;
    my %args = ( expunged => 1,
                 @_ );
    return unless $self->is_auth and $self->is_selected;

    {
        # When we poll, the things that we find should affect this
        # connection as well; hence, the local to be "connection-less"
        local $Net::Server::IMAP::Server->{connection};
        $self->selected->poll;
    }

    for my $s (keys %{$self->untagged_fetch}) {
        my($m) = $self->get_messages($s);
        $self->untagged_response( $s
                . " FETCH "
                . Net::Server::IMAP::Command->data_out( [ $m->fetch([keys %{$self->untagged_fetch->{$s}}]) ] ) );
    }
    $self->untagged_fetch({});

    if ($args{expunged}) {
        # Make sure that they know of at least the existance of what's being expunged.
        my $max = 0;
        $max = $max < $_ ? $_ : $max for @{$self->untagged_expunge};
        $self->untagged_response( "$max EXISTS" ) if $max > $self->previous_exists;

        # Send the expnges, clear out the temporary message store
        $self->previous_exists( $self->previous_exists - @{$self->untagged_expunge} );
        $self->untagged_response( map {"$_ EXPUNGE"} @{$self->untagged_expunge} );
        $self->untagged_expunge([]);
        $self->temporary_messages(undef);
    }

    # Let them know of more EXISTS
    my $expected = $self->previous_exists;
    my $now = @{$self->temporary_messages || $self->selected->messages};
    $self->untagged_response( $now . ' EXISTS' ) if $expected != $now;
    $self->previous_exists($now);
}

sub get_messages {
    my $self = shift;
    my $str  = shift;

    my $messages = $self->temporary_messages || $self->selected->messages;

    my %ids;
    for ( split ',', $str ) {
        if (/^(\d+):(\d+)$/) {
            $ids{$_}++ for $2 > $1 ? $1 .. $2 : $2 .. $1;
        } elsif (/^(\d+):\*$/ or /^\*:(\d+)$/) {
            $ids{$_}++ for @{ $messages } + 0, $1 .. @{ $messages } + 0;
        } elsif (/^(\d+)$/) {
            $ids{$1}++;
        }
    }
    return
        grep {defined} map { $messages->[ $_ - 1 ] } sort {$a <=> $b} keys %ids;
}

sub sequence {
    my $self = shift;
    my $message = shift;

    return $message->sequence unless $self->temporary_messages;
    return $self->temporary_sequence_map->{$message};
}

sub capability {
    my $self = shift;

    my $base = $self->server->capability;
    if ( $self->is_encrypted ) {
        $base = join(" ", grep {$_ ne "STARTTLS"} split(' ', $base));
    } else {
        $base = join(" ", grep {not /^AUTH=\S+$/} split(' ', $base), "LOGINDISABLED");
    }

    return $base;
}

sub log {
    my $self = shift;
    my $msg  = shift;
    chomp($msg);
    warn $msg . "\n";
}

sub out {
    my $self = shift;
    my $msg  = shift;

    if ($self->io_handle) {
        $self->io_handle->blocking(1);
        $self->io_handle->print($msg) or warn "********************** $!\n";
        $self->io_handle->blocking(0);

        $self->log("S(@{[$self->io_handle->peerport]},@{[$self->auth ? $self->auth->user : '???']},@{[$self->is_selected ? $self->selected->full_path : 'unselected']}): $msg");
    } else {
        warn "Connection closed unexpectedly\n";
        $self->close;
    }

}

1;
