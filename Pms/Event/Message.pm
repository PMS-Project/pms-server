#!/usr/bin/perl -w

package Pms::Event::Message;

our @ISA = ("Pms::Event::Event");

sub new(){
  my $class = shift;
  my $self  = $class->SUPER::new();
  bless($self,$class);
  
  $self->{m_user}    = shift;
  $self->{m_channel} = shift;
  $self->{m_message} = shift;
  return $self;
}
1;