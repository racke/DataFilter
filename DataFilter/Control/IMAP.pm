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

	# initialize IMAPClient object, Peek avoids setting on the Seen flag
	$client = new Mail::IMAPClient (Server => $self->{server},
									User => $self->{login},
									Password => $self->{password},
									Socket => $sock,
									Peek => 1,
									Debug => $self->{debug});

	# set state manually to "Connected"
	$client->connect();
	$client->login();

	$self->{client} = $client;
}

sub list {
	my ($self, $folder) = @_;

	if ($folder) {
		unless ($self->{client}->exists($folder)) {
			die "$0: Folder $folder not found\n";
		}
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

sub subject {
	my ($self, $id) = @_;
	my $hdrref;
	
	$hdrref = $self->{client}->parse_headers($id, 'Subject');
	return $hdrref->{Subject}->[0] || '';
}

1;
	
