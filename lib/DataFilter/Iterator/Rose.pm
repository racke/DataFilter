package DataFilter::Iterator::Rose;

use strict;
use warnings;

use base 'DataFilter::Iterator::DBI';

use Rose::DB::Object::QueryBuilder qw(build_select);

=head1 NAME

DataFilter::Iterator::Rose - Iterator class for DataFilter

=cut

=head1 CONSTRUCTOR

=head2 new

Create a DataFilter::Iterator::Rose object with the following parameters:

=over 4

=item dbh

L<DBI> database handle.

=back

=cut

# Constructor
sub new {
	my ($class, @args) = @_;
	my ($self);
	
	$class = shift;
	$self = {@args};
	bless $self, $class;
}

=head1 METHODS

=head2 build

Builds database query. See L<Rose::DB::Object::QueryBuilder> for
instructions.

=cut

# Build method
sub build {
	my ($self) = @_;
	my ($dbref, $sql, $bind);

	$dbref = $self->{query};
	$dbref->{dbh} = $self->{dbh};
	$dbref->{query_is_sql} = 1;

	# prepare database query
	($sql, $bind) = build_select(%$dbref);

	$self->{sql} = $sql;
	$self->{bind} = $bind;
	
	return 1;
}

=head1 AUTHOR

Stefan Hornburg (Racke), <racke@linuxia.de>

=head1 LICENSE AND COPYRIGHT

Copyright 2010-2011 Stefan Hornburg (Racke) <racke@linuxia.de>.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
