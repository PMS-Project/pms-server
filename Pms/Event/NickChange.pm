#!/usr/bin/perl -w

=begin nd

  Package: Pms::Event::NickChange
  
  Description:
  
=cut

package Pms::Event::NickChange;

use strict;
use utf8;
use Pms::Event::Event;
our @ISA = ("Pms::Event::Event");

=begin nd
  Constructor: new
    Initializes the Object
    
  Parameters:
    xxxx - description
=cut
sub new{
  my $class = shift;
  my $self  = $class->SUPER::new();
  bless($self,$class);
  
  $self->{m_connection} = shift;
  $self->{m_oldname}    = shift;
  $self->{m_newname}    = shift;
  return $self;
}

=begin nd
  Function: newName
    <function_description>
  
  Access:
    Public
    
  Parameters:
    
  Returns:
    xxxx
=cut
sub newName{
  my $self = shift or die "Need Ref";
  return $self->{m_newname};
}

=begin nd
  Function: oldName
    <function_description>
  
  Access:
    Public
    
  Parameters:
    
  Returns:
    xxxx
=cut
sub oldName{
  my $self = shift or die "Need Ref";
  return $self->{m_oldname};
}

=begin nd
  Function: connection
    <function_description>
  
  Access:
    Public
    
  Parameters:
    
  Returns:
    xxxx
=cut
sub connection{
  my $self = shift or die "Need Ref";
  return $self->{m_connection};
}
1;