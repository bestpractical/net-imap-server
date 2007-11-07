package Net::Server::IMAP::Command;

use warnings;
use strict;
use bytes;

use base 'Class::Accessor';
use Regexp::Common qw/delimited/;
__PACKAGE__->mk_accessors(qw(server connection command_id options_str command _parsed_options _literals _pending_literal));

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->_parsed_options([]);
    $self->_literals([]);
    return $self;
}

sub validate {
    return 1;
}

sub run {
    my $self = shift;

    $self->bad_command( "command '" . $self->command . "' not recognized" );
}

sub has_literal {
    my $self = shift;
    unless ($self->options_str =~ /\{(\d+)(\+)?\}[\r\n]*$/) {
        $self->parse_options;
        return;
    }

    my $options = $self->options_str;
    my $next = $#{$self->_literals} + 1;
    $options =~ s/\{(\d+)(\+)?\}[\r\n]*$/{{$next}}/;
    $self->_pending_literal($1);
    $self->options_str($options);

    # Pending
    $self->connection->pending(sub {
        my $content = shift;
        if (length $content <= $self->_pending_literal) {
            $self->_literals->[$next] .= $content;
            $self->_pending_literal( $self->_pending_literal - length $content);
        } else {
            $self->_literals->[$next] .= substr($content, 0, $self->_pending_literal, "");
            $self->connection->pending(undef);
            $self->options_str($self->options_str . $content);
            return if $self->has_literal;
            $self->run if $self->validate;
        }
    });
    $self->out( "+ Continue\r\n" ) unless $2;
    return 1;
}

sub parse_options {
    my $self = shift;
    my $str = shift;

    return $self->_parsed_options if not defined $str and not defined $self->options_str;

    my @parsed;
    for my $term (grep {/\S/} split /($RE{delimited}{-delim=>'"'}|$RE{balanced}{-parens=>'()'}|\S+$RE{balanced}{-parens=>'()[]<>'}|\S+)/, defined $str ? $str : $self->options_str) {
        if ($term =~ /^$RE{delimited}{-delim=>'"'}{-keep}$/) {
            push @parsed, $3;
        } elsif ($term =~ /^$RE{balanced}{-parens=>'()'}$/) {
            $term =~ s/^\((.*)\)$/$1/;
            push @parsed, [$self->parse_options($term)];
        } elsif ($term =~ /^\{\{(\d+)\}\}$/) {
            push @parsed, $self->_literals->[$1];
        } else {
            push @parsed, $term;
        }
    }
    return @parsed if defined $str;

    $self->options_str(undef);
    $self->_parsed_options([@{$self->_parsed_options}, @parsed]);
}

sub parsed_options {
    my $self = shift;
    return @{$self->_parsed_options(@_)};
}

sub data_out {
    my $self = shift;
    my $data = shift;
    if ( ref $data eq "ARRAY" ) {
        return "(" . join( " ", map { $self->data_out($_) } @{$data} ) . ")";
    } elsif ( ref $data eq "SCALAR" ) {
        return $$data;
    } elsif ( ref $data eq "HASH") {
        if ($data->{type} eq "string") {
            if ( $data =~ /[{"\r\n%*\\\[]/ ) {
                return "{" . ( length($data->{value}) ) . "}\r\n$data";
            } else {
                return '"' . $data->{value} .'"';
            }
        } elsif ($data->{type} eq "literal") {
            return "{" . ( length($data->{value}) ) . "}\r\n$data";
        }
    } elsif ( not ref $data ) {
        if ( not defined $data ) {
            return "NIL";
        } elsif ( $data =~ /[{"\r\n%*\\\[]/ ) {
            return "{" . ( length($data) ) . "}\r\n$data";
        } elsif ( $data =~ /^\d+$/ ) {
            return $data;
        } else {
            return qq{"$data"};
        }
    }
    return "";
}

sub untagged_response {
    my $self = shift;
    $self->connection->untagged_response(@_);
}

sub tagged_response {
    my $self = shift;
    while ( my $message = shift ) {
        next unless $message;
        $self->untagged_response( uc( $self->command ) . " " . $message );
    }
}

sub send_untagged {
    my $self = shift;

    $self->connection->send_untagged( @_ ) if $self->poll_after;
}

sub ok_command {
    my $self            = shift;
    my $message         = shift;
    my %extra_responses = (@_);
    for ( keys %extra_responses ) {
        $self->untagged_response(
            "OK [" . uc($_) . "] " . $extra_responses{$_} );
    }
    $self->send_untagged;
    $self->out( $self->command_id . " " . "OK " . $message . "\r\n" );
    return 1;
}

sub no_command {
    my $self            = shift;
    my $message         = shift;
    my %extra_responses = (@_);
    for ( keys %extra_responses ) {
        $self->untagged_response(
            "NO [" . uc($_) . "] " . $extra_responses{$_} );
    }
    $self->out( $self->command_id . " " . "NO " . $message . "\r\n" );
    return 0;
}

sub no_failed {
    my $self            = shift;
    my %extra_responses = (@_);
    $self->no_command( uc( $self->command ) . " FAILED", %extra_responses );
}

sub no_unimplemented {
    my $self = shift;
    $self->no_failed( alert => "Feature unimplemented. sorry. We'd love patches!" );
}

sub ok_completed {
    my $self            = shift;
    my %extra_responses = (@_);
    $self->ok_command( uc( $self->command ) . " COMPLETED",
        %extra_responses );
}

sub bad_command {
    my $self   = shift;
    my $reason = shift;
    $self->send_untagged;
    $self->out( $self->command_id . " " . "BAD " . $reason . "\r\n" );
    return 0;
}

sub log {
    my $self = shift;
    $self->connection->log(@_);
}

sub out {
    my $self = shift;
    $self->connection->out(@_);
}

sub poll_after { 1 }

1;
