#!/usr/bin/perl -w

=begin nd

  Package: Pms::Event::Command
  
  Description:
    This Event is fired when a user tries to 
    execute a command registered from a module.
    Its not emitted for buildin commands.
=cut

package Pms::Event::Command;

use strict;
use utf8;
use Pms::Event::Event;

our @ISA = ("Pms::Event::Event");

=begin nd
  Constructor: new
    Initializes the Object
    
  Parameters:
    name - the name of the command
    args - the arguments to the command
=cut
sub new{
  my $class = shift;
  my $self  = $class->SUPER::new();
  bless($self,$class);
  
 
  $self->{m_name} = shift;
  $self->{m_args} = shift;
  
  return $self;
}

=begin nd
  Function: name
    Gets the name of the command
  
  Access:
    Public
    
  Returns:
    a *string* containing the command name
=cut
sub name{
  return $_[0]->{m_name};
}

=begin nd
  Function: args
    Gets the command parameters
  
  Access:
    Public
    
  Returns:
    a *array-ref* to the command params
=cut
sub args{
  return $_[0]->{m_args};
}

1;