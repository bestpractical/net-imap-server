package Net::Server::IMAP::Mailbox;

use warnings;
use strict;

use Email::IMAPFolder;
use Net::Server::IMAP::Message;
use base 'Class::Accessor';

__PACKAGE__->mk_accessors(
    qw(name model force_read_only parent children _path uidnext uids messages)
);

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    $self->init;
    return $self;
}

sub init {
    my $self = shift;

    $self->uidnext(1000);
    $self->messages( [] );
    $self->uids( {} );

    my $name = $self->full_path;
    $name =~ s/\W+/_/g;
    $name .= ".mailbox";
    if ( -e $name ) {
        my $folder = Email::IMAPFolder->new( $name, eol => "\r\n" );
        my @messages = $folder->messages;
        warn "Loaded " . ( @messages + 0 ) . " messages from $name\n";
        $self->add_message($_) for @messages;
    } else {
        warn "No $name file\n";
    }
}

sub add_message {
    my $self    = shift;
    my $message = shift;
    $message->uid( $self->uidnext );
    $self->uidnext( $self->uidnext + 1 );
    $message->sequence( @{ $self->messages } + 1 );
    push @{ $self->messages }, $message;
    $self->uids->{ $message->uid } = $message;
}

sub get_messages {
    my $self = shift;
    my $str  = shift;

    my @ids;
    for ( split ',', $str ) {
        if (/^(\d+):(\d+)$/) {
            push @ids, $1 .. $2;
        } elsif (/^(\d+):\*$/) {
            push @ids, $1 .. @{ $self->messages } + 0;
        } elsif (/^(\d+)$/) {
            push @ids, $1;
        }
    }
    return grep {defined} map { $self->messages->[ $_ - 1 ] } @ids;
}

sub add_child {
    my $self = shift;
    my $node = ( ref $self )
        ->new( { @_, parent => $self, model => $self->model } );
    $self->children( [] ) unless $self->children;
    push @{ $self->children }, $node;
    return $node;
}

sub full_path {
    my $self = shift;
    return $self->_path if $self->_path;

    return $self->name unless $self->parent;
    $self->_path(
        $self->parent->full_path . $self->model->seperator . $self->name );
    return $self->_path;
}

sub flags {
    my $self = shift;
    return qw(\Answered \Flagged \Deleted \Seen \Draft);
}

sub exists {
    my $self = shift;
    return scalar @{ $self->messages };
}

sub recent {
    my $self = shift;
    return 0;
}

sub unseen {
    my $self = shift;
    return undef;
}

sub permanentflags {
    my $self = shift;
    return $self->flags;
}

sub uidvalidity {
    my $self = shift;
    return $^T;
}

sub read_only {
    my $self = shift;
    return $self->force_read_only or 0;
}

sub subscribed {
    my $self = shift;
    return 1;
}

sub expunge {
    my $self = shift;

    my @ids;
    my $offset   = 0;
    my @messages = @{ $self->messages };
    $self->messages( [ grep { not $_->has_flag('\Deleted') } @messages ] );
    for my $m (@messages) {
        if ( $m->has_flag('\Deleted') ) {
            push @ids, $m->sequence - $offset;
            $offset++;
            $m->expunge;
        } elsif ($offset) {
            $m->sequence( $m->sequence - $offset );
        }
    }
    return @ids;
}

1;
