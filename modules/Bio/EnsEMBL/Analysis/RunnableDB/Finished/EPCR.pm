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

Bio::EnsEMBL::Analysis::RunnableDB::Finished::EPCR - 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 METHODS

=cut

=head1 NAME

EPCR.pm 

=head1 SYNOPSIS

  my $runnabledb = Bio::EnsEMBL::Analysis::RunnableDB::Finished::EPCR->
  new(
      -input_id => 'contig::AL805961.22.1.166258:1:166258:1',
      -db => $db,
      -analysis => $analysis,
     );
  $runnabledb->fetch_input;
  $runnabledb->run;
  $runnabledb->write_output;


=head1 DESCRIPTION

The Finished version of EPCR.

=head1 CONTACT

anacode@sanger.ac.uk

=cut

package Bio::EnsEMBL::Analysis::RunnableDB::Finished::EPCR;

use strict;
use warnings;

use Bio::EnsEMBL::Analysis::RunnableDB::EPCR;
use Bio::EnsEMBL::Analysis::Runnable::Finished::EPCR;
use vars qw(@ISA);

@ISA = qw(Bio::EnsEMBL::Analysis::RunnableDB::EPCR);

sub fetch_input{
  my ($self) = @_;
  my %parameters = %{$self->parameters_hash};
  if($self->analysis->db_file){
    $parameters{'-STS_FILE'} = $self->analysis->db_file 
      unless($parameters{'-STS_FILE'});
  }
  if(!$parameters{'-STS_FILE'}){
    my $sts = $self->db->get_MarkerAdaptor->fetch_all;
    throw("No markers in ".$self->db->dbname) unless(@$sts);
    $parameters{'-STS_FEATURES'} = $sts;
  }
  my $slice = $self->fetch_sequence;
  $self->query($slice);
  my $runnable = Bio::EnsEMBL::Analysis::Runnable::Finished::EPCR->new
    (
     -query => $slice,
     -program => $self->analysis->program_file,
     -analysis => $self->analysis,
     %parameters
    );
  $self->runnable($runnable);
}

1;