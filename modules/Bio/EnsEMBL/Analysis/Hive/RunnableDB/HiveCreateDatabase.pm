=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Analysis::Hive::RunnableDB::HiveCreateDatabase

=cut

package Bio::EnsEMBL::Analysis::Hive::RunnableDB::HiveCreateDatabase;

use strict;
use warnings;
use feature 'say';

use File::Basename;
use parent ('Bio::EnsEMBL::Analysis::Hive::RunnableDB::HiveBaseRunnableDB');

use Data::Dumper;

sub param_defaults {
    return {

      # used by all create types
      create_type => '',
      source_db => '',
      target_db => '',
      
      # used by create_type = 'clone'
      script_path => '~/enscode/ensembl-analysis/scripts/clone_database.ksh',

      # used by create_type = 'copy'
      db_dump_file => "/tmp/source_db_".time().".tmp",
      pass_w => '',
      user_w => '',
      ignore_dna => 0, # if set to 1, the dna table won't be dumped
    }
}

sub fetch_input {
  my $self = shift;
  return 1;
}

sub run {
  my $self = shift;

  unless(defined($self->param('create_type'))) {
    $self->throw("You have not defined a create_type flag in you parameters hash! You must provide a create_type (e.g. 'clone')");
  }

  $self->create_db();

  return 1;
}

sub write_output {
  my $self = shift;

  return 1;
}

sub create_db {
  my $self = shift;
  my $create_type = $self->param('create_type');
  if($create_type eq 'clone') {
    $self->clone_db();
  } elsif ($create_type eq 'copy') {
    $self->copy_db();
  } elsif($create_type eq 'core_only') {
    $self->core_only_db();
  } elsif($create_type eq 'backup') {
    $self->make_backup();
  } elsif($create_type eq 'dna_db') {
    $self->create_dna_db();
  } else {
    $self->throw("You have specified a create type of ".$create_type.", however this is not supported by the module");
  }

}

sub clone_db {
  my $self = shift;

  unless($self->param('source_db') && $self->param('target_db')) {
    $self->throw("You have specified a create type of clone but you don't have both a source_db and target_db specified in your config");
  }

  unless($self->param('script_path')) {
    $self->throw("You have specified a create type of clone but you don't have the script_path set in your config, e.g.:\n".
          "~/enscode/ensembl-personal/genebuilders/scripts/clone_database.ksh");
  }

  unless(-e $self->param('script_path')) {
    $self->throw("The path to the clone script you have specified does not exist. Path:\n".$self->param('script_path'));
  }

  my $source_string;
  my $target_string;
  if(ref($self->param('source_db')) eq 'HASH') {
    $source_string = $self->convert_hash_to_db_string($self->param('source_db'));
  } else {
    $self->check_db_string($self->param('source_db'));
    $source_string = $self->param('source_db');
  }

  if(ref($self->param('target_db')) eq 'HASH') {
    $target_string = $self->convert_hash_to_db_string($self->param('target_db'));
  } else {
    $self->check_db_string($self->param('target_db'));
    $target_string = $self->param('target_db');
  }
  my $target_user = $self->param('target_db')->{'-user'};
  my $target_pass = $self->param('target_db')->{'-pass'};
  if (!$target_pass) {
    $target_user = $self->param_required('user_w');
    $target_pass = $self->param_required('pass_w');
  }

  my $command = "ksh ".$self->param('script_path')." -f -l -s ".$source_string.' -r '.$self->param('source_db')->{'-user'}." -t ".$target_string.' -w '.$target_user.' -P '.$target_pass;
  say "COMMAND: ".$command;

  my $exit_code = system($command);
  if($exit_code) {
    $self->throw("The clone script exited with a non-zero exit code (did the target_db already exist?): ".$exit_code);
  }

}

sub copy_db {
  my $self = shift;

  if (not $self->param('source_db') or not $self->param('target_db')) {
    $self->throw("You have specified a create type of copy but you don't have both a source_db and target_db specified in your config.");
  }

  if (not $self->param('user_w') or not $self->param('pass_w')) {
    $self->throw("You have specified a create type of copy but you haven't specified the user_w and pass_w.\n");
  }

  if (not $self->param('db_dump_file')) {
    $self->throw("You have specified a create type of copy but you haven't specified a db_dump_file which will be used as a temporary file.");
  } else {
  	my $dump_dir = dirname($self->param('db_dump_file'));
  	`mkdir -p $dump_dir`;
  	if (!(-e $dump_dir)) {
      $self->throw("Couldn't create $dump_dir directory.");
  	}
  }

  my $source_string;
  my $target_string;
  if (ref($self->param('source_db')) eq 'HASH') {
    $source_string = $self->convert_hash_to_db_string($self->param('source_db'));
  } else {
    $self->check_db_string($self->param('source_db'));
    $source_string = $self->param('source_db');
  }

  if (ref($self->param('target_db')) eq 'HASH') {
    $target_string = $self->convert_hash_to_db_string($self->param('target_db'));
  } else {
    $self->check_db_string($self->param('target_db'));
    $target_string = $self->param('target_db');
  }
  
  my @source_string_at_split = split('@',$source_string);
  my $source_dbname = shift(@source_string_at_split);
  my @source_string_colon_split = split(':',shift(@source_string_at_split));
  my $source_host = shift(@source_string_colon_split);
  my $source_port = shift(@source_string_colon_split);
  
  my @target_string_at_split = split('@',$target_string);
  my $target_dbname = shift(@target_string_at_split);
  my @target_string_colon_split = split(':',shift(@target_string_at_split));
  my $target_host = shift(@target_string_colon_split);
  my $target_port = shift(@target_string_colon_split);

  if($self->param('force_drop')) {
    $self->drop_database($target_host,$target_port,$self->param('user_w'),$self->param('pass_w'),$target_dbname);
  }

  $self->dump_database($self->param('source_db'), $self->param('db_dump_file'), $self->param('ignore_dna'));
  $self->create_database($target_host,$target_port,$self->param('user_w'),$self->param('pass_w'),$target_dbname);
  $self->load_database($self->param('target_db'), $self->param('db_dump_file'));
  $self->remove_file($self->param('db_dump_file'));
}

sub core_only_db {
  my $self = shift;

  unless ($self->param('target_db')) {
    $self->throw("You have specified a create type of core_only but you don't have a target_db specified in your config.");
  }

  unless($self->param('user_w') && $self->param('pass_w')) {
    $self->throw("You have specified a create type of core_only but you haven't specified the user_w and pass_w.\n");
  }

  unless($self->param('enscode_root_dir')) {
    $self->throw("You have specified a create type of core_only but you haven't specified the enscode_root_dir path\n");
  }

  my $table_file = $self->param('enscode_root_dir')."/ensembl/sql/table.sql";
  unless(-e $table_file) {
    $self->throw("You have specified a create type of core_only but the path from enscode_root_dir to the table file is incorrect:\n".
          $self->param('enscode_root_dir')."/ensembl/sql/table.sql");
  }

  my $target_string;
  if (ref($self->param('target_db')) eq 'HASH') {
    $target_string = $self->convert_hash_to_db_string($self->param('target_db'));
  } else {
    $self->check_db_string($self->param('target_db'));
    $target_string = $self->param('target_db');
  }

  my @target_string_at_split = split('@',$target_string);
  my $target_dbname = shift(@target_string_at_split);
  my @target_string_colon_split = split(':',shift(@target_string_at_split));
  my $target_host = shift(@target_string_colon_split);
  my $target_port = shift(@target_string_colon_split);
  my $target_user = $self->param('user_w');
  my $target_pass = $self->param('pass_w');

  my $command;
  # Create the empty db
  if($target_port) {
    $command = "mysql -h".$target_host." -u".$target_user." -p".$target_pass." -P".$target_port." -e 'CREATE DATABASE ".$target_dbname."'";
  } else {
    $command = "mysql -h".$target_host." -u".$target_user." -p".$target_pass." -e 'CREATE DATABASE ".$target_dbname."'";
  }
  say "COMMAND: ".$command;

  my $exit_code = system($command);
  if($exit_code) {
    $self->throw("The create database command exited with a non-zero exit code: ".$exit_code);
  }

  # Load core tables
  if($target_port) {
    $command = "mysql -h".$target_host." -u".$target_user." -p".$target_pass." -P".$target_port." -D".$target_dbname." < ".$table_file;
  } else {
    $command = "mysql -h".$target_host." -u".$target_user." -p".$target_pass." -D".$target_dbname." < ".$table_file;
  }
  $exit_code = system($command);
  if($exit_code) {
    $self->throw("The load tables command exited with a non-zero exit code: ".$exit_code);
  }

}

sub make_backup {
  my $self = shift;

  unless ($self->param('source_db')) {
    $self->throw("You have specified a create type of backup but you don't have a source_db specified in your config.");
  }

  unless ($self->param('user_w') && $self->param('pass_w')) {
    $self->throw("You have specified a create type of backup but you haven't specified the user_w and pass_w, these are".
                 " sometimes needed for dumping dbs with views");
  }

  unless ($self->param('output_path')) {
    $self->throw("You have specified a create type of backup but you don't have an output_path param set");
  }

  unless ($self->param('backup_name')) {
    $self->throw("You have specified a create type of backup but haven't specified a file name with the backup_name param");
  }

  unless (-e $self->param('output_path')) {
    my $cmd = "mkdir -p ".$self->param('output_path');
    my $return = system($cmd);
    if($return) {
      $self->throw("The output path specified did not exist and mkdir -p failed to create it. Commandline used:\n".$cmd);
    }
  }

  my $source_db = $self->param('source_db');

  my $dump_file = $self->param('output_path')."/".$self->param('backup_name');

  $self->dump_database($source_db,
                       $dump_file,
                       $self->param('ignore_dna'),
                       1);
}

sub convert_hash_to_db_string {
  my ($self,$connection_info) = @_;

  unless(defined($connection_info->{'-dbname'}) && defined($connection_info->{'-host'})) {
    $self->throw("You have passed in a hash as your db info however the hash is missing either the dbname or host key,".
          " both are required if a hash is being passed in");
  }

  my $port = $connection_info->{'-port'};

  my $db_string;
  $db_string = $connection_info->{'-dbname'}.'@'.$connection_info->{'-host'};
  if(defined($port)) {
    $db_string .= ':'.$port;
  }

  $self->check_db_string($db_string);
  return($db_string);
}

sub check_db_string {
  my ($self,$db_string) = @_;

  unless($db_string =~ /[^\@]+\@[^\:]+\:\d+/ || $db_string =~ /[^\@]+\@[^\:]+/) {
    $self->throw("Parsing check on the db string failed.\ndb string:\n".$db_string.
          "\nExpected format:\nmy_db_name\@myserver:port or my_db_name\@myserver");
  }
}

sub dump_database {

  my ($self, $db, $db_file, $ignore_dna, $compress, $tables) = @_;

  my $dbhost = $db->{'-host'};
  my $dbport = $db->{'-port'};
  my $dbpass = $db->{'-pass'};
  my $dbuser = $db->{'-user'};
  my $dbname = $db->{'-dbname'};
  print "\nDumping database $dbname"."@"."$dbhost:$dbport...\n";
  
  if ($self->param_is_defined('user_w')) {
    $dbuser = $self->param('user_w');
  }
  if ($self->param_is_defined('pass_w')) {
    $dbpass = $self->param('pass_w');
  }
  my $command;
  if (!$dbpass) { # dbpass for read access can be optional
  	$command = "mysqldump -h$dbhost -P$dbport -u$dbuser ";
  } else {
  	$command = "mysqldump -h$dbhost -P$dbport -u$dbuser -p$dbpass";
  }
  # Check the max_allowed_packet before dumping tables
  my $max_allowed_packet;
  my $checkcmd = $command;
  $checkcmd =~ s/dump/admin/;
  open(RH, $checkcmd.' variables |') || $self->throw("Coudl not execute command: $checkcmd variables");
  while(<RH>) {
    if (/max_allowed_packet\D+(\d+)/) {
      $max_allowed_packet = $1;
      last;
    }
  }
  close(RH) || $self->throw("Could not close: $checkcmd variables");
  if ($max_allowed_packet) {
    $command .= ' --max_allowed_packet '.$max_allowed_packet;
  }
  if ($ignore_dna) {
  	$command .= " --ignore-table=".$dbname.".dna ";
  }
  $command .= " $dbname";
  if ($tables and @$tables) {
    $command .= ' '.join(' ', @$tables);
  }
  if ($compress) {
    # If pipefail is not set your command can fail without telling you
    $command = "set -o pipefail; $command | gzip > $db_file.gz";
  }
  else {
    $command .= " > $db_file";
  }

  if (system($command)) {
    $self->throw("The dump was not completed. Please, check the command or that you have enough disk space in the output path $db_file as well as writing permission.");
  } else {
    print("The database dump was completed successfully into file $db_file\n");
  }
}

sub create_database {
  my ($self, $dbhost,$dbport,$dbuser,$dbpass,$dbname) = @_;
  print "Creating database $dbname"."@"."$dbhost:$dbport...\n";
  if (system("mysql -h$dbhost -P$dbport -u$dbuser -p$dbpass -e'CREATE DATABASE $dbname' ")) {
    $self->throw("Couldn't create database  $dbname"."@"."$dbhost:$dbport. Please, check that it does not exist and you have write access to be able to perform this operation.");
  } else {
    print("Database $dbname"."@"."$dbhost:$dbport created successfully.\n");
  }
}

sub load_database {
  my ($self, $db, $db_file) = @_;

  my $dbhost = $db->{'-host'};
  my $dbport = $db->{'-port'};
  my $dbpass = $db->{'-pass'};
  my $dbuser = $db->{'-user'};
  my $dbname = $db->{'-dbname'};

  if ($self->param_is_defined('user_w')) {
    $dbuser = $self->param('user_w');
  }
  if ($self->param_is_defined('pass_w')) {
    $dbpass = $self->param('pass_w');
  }
  print "\nLoading file $db_file into database $dbname"."@"."$dbhost:$dbport...\n";
  if (system("mysql -h$dbhost -P$dbport -u$dbuser -p$dbpass -D$dbname < $db_file")) {
    $self->throw("The database loading process failed. Please, check that you have access to the file $db_file and the database you are trying to write to.");
  } else {
    print("\nThe database loading process was completed successfully from file $db_file into $dbname.\n");
  }
}

sub drop_database {
  my ($self, $dbhost,$dbport,$dbuser,$dbpass,$dbname) = @_;
  print "\nDropping existing database if it exists $dbname"."@"."$dbhost:$dbport...\n";
  system("mysql -h$dbhost -P$dbport -u$dbuser -p$dbpass -e 'DROP DATABASE $dbname'");
}

sub remove_file {
  my ($self, $db_file) = @_;

  if (-e $db_file) {
  	print "Deleting file $db_file\n";
  	if (system("rm -f $db_file")) {
      $self->throw("Couldn't delete file $db_file");
  	} else {
  	  print "File $db_file has been deleted.\n";
  	}
  }
}


sub create_dna_db {
  my ($self) = @_;

  $self->clone_db;
  $self->dump_database($self->param('source_db'), $self->param('db_dump_file'), 0, 0, ['dna', 'repeat_feature', 'repeat_consensus']);
  $self->load_database($self->param('target_db'), $self->param('db_dump_file'));
}

sub max_allowed_packet {
  my ($self, $max_allowed_packet) = @_;

  if (defined $max_allowed_packet) {
    $self->param('max_allowed_packet', $max_allowed_packet);
  }
  elsif (!$self->param_is_defined('max_allowed_packet')) {
    open(RH, 'mysqldump variables |') || $self->throw("Coudl not execute command: mysqldump variables");
    while(<RH>) {
      if (/max_allowed_packet\D+(\d+)/) {
        $max_allowed_packet = $1;
        last;
      }
    }
    close(RH) || $self->throw("Could not close: mysqldump variables");
    $self->param('max_allowed_packet', $max_allowed_packet);
  }
  if ($self->param_is_defined('max_allowed_packet')) {
    return $self->param('max_allowed_packet');
  }
  else {
    return;
  }
}

1;





