package Net::Server::IMAP::Command::Create;
use base qw/Net::Server::IMAP::Command/;

sub run {
  my $self = shift;
  my $boxname = shift; 
  if ($boxname =~ /^INBOX$/) {
    $self->no_failed("You can't create the INBOX");
  }

  $self->ok_completed("CREATE Completed");

}

1;
