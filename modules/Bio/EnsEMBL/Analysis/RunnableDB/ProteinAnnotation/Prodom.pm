=head1 LICENSE

  Copyright (c) 1999-2011 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=cut

=head1 NAME

Bio::EnsEMBL::Analysis::RunnableDB::ProteinAnnotation::Prodom - 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 METHODS

=cut

# Author: Gary Williams (gw3@sanger.ac.uk)
# Copyright (c) Marc Sohrmann, 2001
# You may distribute this code under the same terms as perl itself
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

  Bio::EnsEMBL::Analysis::RunnableDB::ProteinAnnotation::Prodom

=head1 SYNOPSIS

  my $seg = Bio::EnsEMBL::Analysis::RunnableDB::ProteinAnnotation::Prodom->new ( -db      => $db,
	    	                                                                 -input_id   => $input_id,
                                                                                 -analysis   => $analysis,
                                                                               );
  $seg->fetch_input;  # gets sequence from DB
  $seg->run;
  $seg->output;
  $seg->write_output; # writes features to to DB

=head1 DESCRIPTION

  This object wraps Bio::EnsEMBL::Analysis::Runnable::Prodom
  to add functionality to read and write to databases.
  A Bio::EnsEMBL::Analysis::DBSQL::DBAdaptor is required for database access (db).
  The query sequence is provided through the input_id.
  The appropriate Bio::EnsEMBL::Analysis object
  must be passed for extraction of parameters.

=head1 CONTACT

  Gary Williams

=head1 APPENDIX

  The rest of the documentation details each of the object methods. 
  Internal methods are usually preceded with a _.

=cut

package Bio::EnsEMBL::Analysis::RunnableDB::ProteinAnnotation::Prodom;

use strict;
use vars qw(@ISA);

use Bio::EnsEMBL::Analysis::RunnableDB::ProteinAnnotation;
use Bio::EnsEMBL::Analysis::Runnable::ProteinAnnotation::Prodom;

@ISA = qw(Bio::EnsEMBL::Analysis::RunnableDB::ProteinAnnotation);




# runnable method

sub fetch_input {
	my ($self,@args)=@_;
	$self->SUPER::fetch_input(@args);
	my $run = Bio::EnsEMBL::Analysis::Runnable::ProteinAnnotation::Prodom->new( -query    => $self->query,
	                                                                            -analysis => $self->analysis);
	$self->runnable($run)
}
1;
