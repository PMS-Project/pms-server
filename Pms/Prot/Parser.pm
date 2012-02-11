#!/usr/bin/perl -w

package Pms::Prot::Parser;
use strict;

sub new{
  my $class = shift;
  my $self = {};
  bless($self,$class);
  
  $self->{m_lastError} = undef;
  
  return $self;
}

sub parseMessage (){
  my $self = shift;
  my $message = shift;
  
  #reverse string so we can always grab the last character
  $message = reverse $string;
  
  my $char = chop($message);
  if($char ne "/"){
    $self->{m_lastError} = "First element of message has to be a /";
    return 0; #error
  }
  
  #first we need a token , its the command name
  my $name = $self->parseToken(\$message);
  if(!defined $name){
    return 0; #error
  }
  
  my @arguments;
  while(1){
    #don't cut the first element out so the subparser can read it
    consumeWhitespace(\$message);
    if(!length($message)){
      last;
    }
    my $char = substr($message,length($message)-1,1);
    my $arg  = undef;
    if($char eq "\"" || $char eq "'"){
      $arg = $self->parseString(\$message);
    }elsif($char =~ m/[0-9|+|-|\.]/){
      $arg = $self->parseNumber(\$message);
    }else{
      $arg = $self->parseToken(\$message);
    }
    if(!defined $arg){
      return 0;
    }
    
    push(@arguments,$arg);
  }
  
  my %funcCall = ('name' => $name,
                  'args' => @arguments);
  return %funcCall;
}

sub consumeWhitespace(){
  my $message = shift;
  $$message =~ s/^\s+//; #remove leading spaces
}

sub parseToken (){
  my $self = shift;
  my $message = shift;
  my $token;
  my $firstChar = 1;
  
  while(length($$message)){
    my $char = chop($$message);
    if($char eq " "){ #space seperates arguments
      return $token;
    }
    if($firstChar){
      #The first char can not be a number
      if($char ~= m/[A-Za-z_]/){
        $firstChar = 0;
        $token .= $char;
        next;
      }
    }else{
      if($char ~= m/[A-Za-z0-9_]/){
        $token .= $char;
        next;
      }
    }
    $self->{m_lastError} = "A token can only contain the following chars: [A-Za-z0-9_] and can NOT start with a number";
    return undef; #error
  }
  $self->{m_lastError} = "Empty token";
  return undef;
}

sub parseString (){
  my $self = shift;
  my $message = shift;
  my $firstChar = 1;
  my $string;
  
  my $quotes = chop($$message);
  
  while(length($$message)){
    my $char = chop($$message);
    
    if($char eq "\\"){
      #escaping just append the next char
      next;
    }
    
    #we hit the end of the string return to parent
    if($char eq $quotes){
      return $string;
    }
    
    $string .= $char;
  }
  #if we did not hit the end of the string we have a error
  $self->{m_lastError} = "String is missing its end quotes";
  return undef;
}

sub parseNumber (){
  my $self = shift;
  return undef;
}