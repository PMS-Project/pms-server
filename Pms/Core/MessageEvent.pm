#!/usr/bin/perl -w;

package Pms::Core::MessageEvent;

our @ISA = ("Pms::Core::Event");

sub new(){
  my $class = shift;
  my $self  = $class->SUPER::new();
  bless($self,$class);
  
  $self->{m_user}    = undef;
  $self->{m_channel} = undef;
  $self->{m_message} = undef;
  return $self;
}
1;