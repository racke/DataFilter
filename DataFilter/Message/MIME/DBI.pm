# DataFilter::Message::MIME::DBI

# Copyright 2004 by Stefan Hornburg (Racke) <racke@linuxia.de>

package DataFilter::Message::MIME::DBI;

use strict;
use warnings;

use DataFilter::Message::MIME;

use vars qw(@ISA);
@ISA = qw(DataFilter::Message::MIME);

sub new {
	my $proto = shift;
	my $class = ref ($proto) || $proto;
	my $self = $class->SUPER::new();

	$self->{dbif} = new DBIx::Easy (@_);

	bless ($self, $class);
	return $self;
}

sub store {
	my ($self, $token, $owner) = @_;
	
	my $id = $self->{dbif}->insert('messages',
								   token => $token,
								   owner => $owner);
	$self->store_headers($id);
	$self->store_parts($id);
}

sub store_parts {
	my ($self, $id) = @_;

	
}

sub store_headers {
	my ($self, $id) = @_;

	my @hlist = $self->headers();
	
	for (@hlist) {
		$self->{dbif}->insert('message_headers',
							  name => $_->{name},
							  value => $_->{value},
							  pos => $_->{pos},
							  msg_ref => $id);
	}
	
}

1;
