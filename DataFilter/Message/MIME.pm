# DataFilter::Message::MIME

# Copyright 2004 by Stefan Hornburg (Racke) <racke@linuxia.de>

package DataFilter::Message::MIME;

use strict;
use warnings;

use MIME::Parser;

use DBIx::Easy;

sub new {
	my $proto = shift;
	my $class = ref ($proto) || $proto;
	my $self = {parser => new MIME::Parser};

	bless ($self, $class);
	return $self;
}

sub headers {
	my ($self) = @_;

	unless (exists $self->{_headerlist}) {
		$self->parse_headers();
	}

	@{$self->{_headerlist}};
}

sub parse {
	my ($self, $input) = @_;

	eval {
		$self->{_ent} = $self->{parser}->parse($input);
	};

	if ($@) {
		die "$0: MIME errors: $@\n";
	}
}

sub parse_headers {
	my ($self) = @_;
	my ($headobj);
	
	my $i = 1;
	my (%headers, @hdrs, @headerlist);

	$headobj = $self->{_ent}->head();
	
	for (split(/\n/, $headobj->as_string)) {
		if (/^([\w-]+):/) {
			next if exists $headers{$1};
			@hdrs = $headobj->get_all($1);
			$headers{$1} = \@hdrs;
			for (my $i = 0; $i < @hdrs; $i++) {
				chomp($hdrs[$i]);
				push (@headerlist, {name => $1, pos => $i,
									value => $hdrs[$i]});
			}
		}
	}
		
	$self->{_headermap} = \%headers;
	$self->{_headerlist} = \@headerlist;
}

sub store_parts {
}

sub store_headers {
}

1; 
