package Net::Server::IMAP::Connection;

use warnings;
use strict;

use base 'Class::Accessor';

use Net::Server::IMAP::Command;

__PACKAGE__->mk_accessors(qw(server io_handle selected model pending));

sub new {
    my $class = shift;
    my $self = $class->SUPER::new( { @_, state => "unauth" } );
    $self->greeting;
    return $self;
}

sub greeting {
    my $self = shift;
    $self->out( '* OK IMAP4rev1 Server' . "\r\n" );
}

sub handle_command {
    my $self    = shift;
    my $content = $self->io_handle->getline();

    unless ( defined $content ) {
        $self->log("Connection closed by remote host");
        $self->close;
        return;
    }

    $self->log("C: $content");

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

    $handler->run() if $handler->validate;
}

sub close {
    my $self = shift;
    $self->server->connections->{ $self->io_handle } = undef;
    $self->server->select->remove( $self->io_handle );
    $self->io_handle->close;
}

sub parse_command {
    my $self = shift;
    my $line = shift;
    $line =~ s/[\r\n]+$//;
    unless ( $line =~ /^([\w\d]+)\s+(\w+)(?:\s+(.+?))?$/ ) {
        if ( $line !~ /^([\w\d]+)\s+/ ) {
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

sub auth {
    my $self = shift;
    if (@_) {
        warn "@{[caller]}\n";
        $self->{auth} = shift;
        $self->server->model_class->require || warn $@;
        $self->model(
            $self->server->model_class->new( { auth => $self->{auth} } ) );
    }
    return $self->{auth};
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
    $self->io_handle->print($msg);
    $self->log("S: $msg");
}

1;
