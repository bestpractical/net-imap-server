package Net::Server::IMAP::Mailbox;

use warnings;
use strict;

use Net::Server::IMAP::Message;
use base 'Class::Accessor';

__PACKAGE__->mk_accessors(
    qw(name is_inbox parent children _path uidnext uids uidvalidity messages subscribed is_selectable)
);

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    return if $self->parent and grep {$self->full_path eq $_->full_path} @{$self->parent->children};
    $self->init;
    $self->load_data;
    return $self;
}

sub init {
    my $self = shift;

    $self->uidnext(1000);
    $self->messages( [] );
    $self->uids( {} );
    $self->children( [] );
    $self->uidvalidity( scalar time );
    $self->subscribed( 1 );
    $self->is_selectable( 1 );
}

sub load_data {
    my $self = shift;
    my $name = $self->full_path;
    return unless $name;
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

sub seperator {
    return "/";
}

sub selected {
    my $self = shift;
    return $Net::Server::IMAP::Server->connection->selected
      and $Net::Server::IMAP::Server->connection->selected eq $self;
}

sub add_message {
    my $self    = shift;
    my $message = shift;

    # Basic message setup first
    $message->mailbox($self);
    $message->sequence( @{ $self->messages } + 1 );
    push @{ $self->messages }, $message;

    # Some messages may supply their own uids
    if ($message->uid) {
        $self->uidnext( $message->uid + 1 ) if $message->uid >= $self->uidnext;
    } else {
        $message->uid( $self->uidnext );
        $self->uidnext( $self->uidnext + 1 );
    }
    $self->uids->{ $message->uid } = $message;

    # Also need to add it to anyone that has this folder as a
    # temporary message store
    for my $c (Net::Server::IMAP->concurrent_mailbox_connections($self)) {
        next unless $c->temporary_messages;

        push @{$c->temporary_messages}, $message;
        $c->temporary_sequence_map->{$message} = scalar @{$c->temporary_messages};
    }
    return $message;
}

sub get_uids {
    my $self = shift;
    my $str  = shift;

    my %ids;
    for ( split ',', $str ) {
        if (/^(\d+):(\d+)$/) {
            $ids{$_}++ for $2 > $1 ? $1 .. $2 : $2 .. $1;
        } elsif (/^(\d+):\*$/ or /^\*:(\d+)$/) {
            $ids{$_}++ for $self->uidnext - 1, $1 .. $self->uidnext - 1;
        } elsif (/^(\d+)$/) {
            $ids{$1}++;
        }
    }
    return
        grep {defined} map { $self->uids->{$_} } sort {$a <=> $b} keys %ids;
}

sub add_child {
    my $self = shift;
    my $node = ( ref $self )
        ->new( { @_, parent => $self } );
    return unless $node;
    push @{ $self->children }, $node;
    return $node;
}

sub create {
    my $self = shift;
    return $self->add_child(@_);
}

sub reparent {
    my $self = shift;
    my $parent = shift;

    $self->parent->children([grep {$_ ne $self} @{$self->parent->children}]);
    push @{$parent->children}, $self;
    $self->parent($parent);
    my @uncache = ($self);
    while (@uncache) {
        my $o = shift @uncache;
        $o->_path(undef);
        push @uncache, @{$o->children};
    }
    return 1;
}

sub delete {
    my $self = shift;
    $self->parent->children([grep {$_ ne $self} @{$self->parent->children}]);

    return 1;
}

sub full_path {
    my $self = shift;
    return $self->_path if defined $self->_path;
    $self->_path(
                 !$self->parent ? "" :
                 !$self->parent->parent ? $self->name :
        $self->parent->full_path . $self->seperator . $self->name );
    return $self->_path;
}

sub flags {
    my $self = shift;
    return qw(\Answered \Flagged \Deleted \Seen \Draft);
}

sub can_set_flag {
    my $self = shift;
    my $flag = shift;

    return 1 if grep {lc $_ eq lc $flag} $self->flags;
    return;
}

sub exists {
    my $self = shift;
    $Net::Server::IMAP::Server->connection->previous_exists( scalar @{ $self->messages } )
      if $self->selected;
    return scalar @{ $self->messages };
}

sub recent {
    my $self = shift;
    return scalar grep {$_->has_flag('\Recent')} @{$self->messages};
}

sub unseen {
    my $self = shift;
    return scalar grep {not $_->has_flag('\Seen')} @{$self->messages};
}

sub permanentflags {
    my $self = shift;
    return $self->flags;
}

sub read_only {
    my $self = shift;
    return 0;
}

sub expunge {
    my $self = shift;
    my $only = shift;
    return if $only and not @{$only};
    my %only; $only{$_}++ for @{$only || []};

    my @ids;
    my $offset   = 0;
    my @messages = @{ $self->messages };
    $self->messages( [ grep { not ( $_->has_flag('\Deleted') and (not $only or $only{$_->sequence}))} @messages ] );
    for my $c (Net::Server::IMAP->concurrent_mailbox_connections($self)) {
        # Ensure that all other connections with this selected get a
        # temporary message list, if they don't already have one
        unless (($Net::Server::IMAP::Server->connection and $c eq $Net::Server::IMAP::Server->connection)
             or $c->temporary_messages) {
            $c->temporary_messages([@messages]);
            $c->temporary_sequence_map({});
            $c->temporary_sequence_map->{$_} = $_->sequence for @messages;
        }
    }

    for my $m (@messages) {
        if ( $m->has_flag('\Deleted') and (not $only or $only{$m->sequence})) {
            push @ids, $m->sequence - $offset;
            delete $self->uids->{$m->uid};
            $offset++;
            $m->expunge;
        } elsif ($offset) {
            $m->sequence( $m->sequence - $offset );
        }
    }

    for my $c (Net::Server::IMAP->concurrent_mailbox_connections($self)) {
        # Also, each connection gets these added to their expunge list
        push @{$c->untagged_expunge}, @ids;
    }
}

sub append {
    my $self = shift;
    my $m = Net::Server::IMAP::Message->new(@_);
    $m->set_flag('\Recent', 1);
    $self->add_message($m);
    return $m;
}

sub poll {}

sub prep_for_destroy {
    my $self = shift;
    my @kids = @{$self->children || []};
    $self->children([]);
    $_->prep_for_destroy for @kids;
    my @messages = @{$self->messages || []};
    $self->messages([]);
    $_->prep_for_destroy for @messages;
    $self->parent(undef);
}

package Email::IMAPFolder;
use base 'Email::Folder';
use YAML;

sub bless_message {
    my $self = shift;
    my $message = shift || "";

    return Net::Server::IMAP::Message->new($message);
}

1;