#! /usr/bin/perl
#
# Copyright 2003 by Stefan Hornburg (Racke) <racke@linuxia.de>

package Stock::Materialboerse;
use vars qw(@ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter);

use DBIx::Easy;

sub new {
	my $proto = shift;
	my $class = ref ($proto) || $proto;
	my $self = {};

	bless ($self, $class);
	return $self;
}

sub key_columns {
	my ($self, @columns) = @_;

	for (@columns) {
		$self->{KEY_COLUMNS}->{$_} = 1;
	}
}

sub import_components {
	my ($self, $company_idf, $componentlist) = @_;
	my $dbif = new DBIx::Easy ('mysql', 'matstock');

	# initially mark components as deleted
	$dbif->update('component', "company_idf = $company_idf", deleted => 1);

	@columns = @{$componentlist->[0]};
	
	for (my $row = 1; $row < @$componentlist; $row++) {
		my %key_columns = (company_idf => $company_idf);
		my %comphash = (company_idf => $company_idf);
		
		for (my $col = 0; $col < @columns; $col++) {
			if (exists $self->{KEY_COLUMNS}->{$columns[$col]}) {
				$key_columns {$columns[$col]} = $componentlist->[$row]->[$col];
			}
			$comphash {$columns[$col]} = $componentlist->[$row]->[$col];
		}

		my @colconds;
		for (keys %key_columns) {
			push (@colconds, "$_ = " . $dbif->quote($key_columns{$_}));
		}

		$comphash{sell} = 1;
		$comphash{pricing} = 'rfq';
		
		my $sth = $dbif->process ("select * from component where " . join(' AND ', @colconds));
		if ($sth->rows == 0) {
			$dbif->insert('component', %comphash);
		} elsif ($sth->rows == 1) {
			$comphash{deleted} = 0;
			$dbif->update('component', join(' AND ', @colconds), %comphash);
		} else {
			warn "two many matching components found\n";
		}
	}

	# delete components no longer in the list for the updates
	$dbif->delete('component', "company_idf = $company_idf AND deleted = 1");
};

1;
