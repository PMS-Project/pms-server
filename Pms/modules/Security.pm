#!/usr/bin/perl -w

package Security;

use strict;
use Pms::Event::Connect;

sub new (){
  my $class = shift;
  my $self  = {};
  bless ($self, $class);
  
  $self->{m_parent} = shift;
  $self->{m_eventGuard} = undef;
  $self->initialize();
  
  warn "Security Module created";
  return $self;
}

sub DESTROY(){
  my $self = shift;
  $self->shutdown();
}

sub initialize (){
  my $self = shift;
  $self->{m_eventGuard} = $self->{m_parent}->connect( 
    change_nick_request => sub{
      my $eventChain = shift;
      my $eventType  = shift;
      
      if($eventType->newName() eq "muhla"){
        $eventType->reject("Registered Nickname, use the identify command to identify yourself.");
        $eventChain->stop_event;
      }
    }
  );
  $self->{m_parent}->registerCommand("identify",$self->_identifyCallback());
}

sub shutdown (){
  my $self = shift;
  warn "Shutting Down";
  $self->{m_parent}->disconnect($self->{m_eventGuard});
}

sub _identifyCallback(){
  my $self = shift;
  return sub{
    my $connection = shift;
    my $nickname = shift;
    my $password = shift;
    
    if($nickname eq "muhla" && $password eq "muhlamuhla"){
      $self->{m_parent}->changeNick($connection, $nickname,1); #change nick and force the change
    }
  }
}



1;