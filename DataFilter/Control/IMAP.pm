# DataFilter::Control::IMAP

# Copyright 2004 by Stefan Hornburg (Racke) <racke@linuxia.de>

package DataFilter::Control::IMAP;

use IO::Socket::SSL 0.90;
use Mail::IMAPClient;

sub new {
	my $proto = shift;
	my $class = ref ($proto) || $proto;
	my $self = {@_};

	bless ($self, $class);
	return $self;
}

sub connect {
	my $self = shift;
	my ($sock, $client);

	my $sock = IO::Socket::SSL->new (Proto => 'tcp',
									 SSL_verify_mode => 0x00,
									 PeerAddr=> $self->{server},
									 PeerPort=> 993);

	unless ($sock) {
		die "$0: unable to create SSL connection: ",
		&IO::Socket::SSL::errstr(), "\n";
	}

	$client = new Mail::IMAPClient (Server => $self->{server},
									User => $self->{login},
									Password => $self->{password},
									Socket => $sock);

	# set state manually to "Connected"
	$client->{State} = 1;
	$client->login();

	$self->{client} = $client;
}

sub list {
	my ($self, $folder) = @_;

	if ($folder) {
		print "Messages in folder $folder: ", $self->{client}->message_count($folder), "\n";
		$self->{client}->select($folder);
		$self->{client}->search('ALL');
	} else {
		$self->{client}->folders();
	}
}

sub data {
	my ($self, $id) = @_;

	$self->{client}->message_string($id);
}

1;
	
