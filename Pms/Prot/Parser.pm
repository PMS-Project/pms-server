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
  my $string = shift;
  my $message;
  
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
    consumeWhitespace(\$message);
    if(!length($message)){
      last;
    }
    
    #print "remaining message: '".$message."'\n";
    
    #don't cut the first element out so the subparser can read it
    my $char = substr($message,length($message)-1,1);
    #print "Next Char: '".$char."'\n";
    my $arg  = undef;
    if($char eq "\"" || $char eq "'"){
      $arg = $self->parseString(\$message);
    }elsif($char =~ m/^[0-9|+|\-|\.]$/){ #a number can start with 0-9 + - or a . 
      $arg = $self->parseNumber(\$message);
    }
    if(!defined $arg){
      return undef;
    }
    
    push(@arguments,$arg);
  }
  
  my %funcCall = ('name' => $name,
                  'args' => @arguments);
  
  #print "\nParsed:\n ".%funcCall;
  
  return %funcCall;
}

sub consumeWhitespace(){
  my $message = shift;
  $$message =~ s/\s+$//; #remove leading spaces
}

sub parseToken (){
  my $self = shift;
  my $message = shift;
  my $token;
  my $firstChar = 1;
  
  #print "Parse Token \n";
  
  while(length($$message)){
    my $char = chop($$message);
    if($char eq " "){ #space seperates arguments
      #print "parsed token: ".$token."\n";
      return $token;
    }
    if($firstChar){
      #The first char can not be a number
      if($char =~ m/[A-Za-z_]/){
        $firstChar = 0;
        $token .= $char;
        next;
      }
    }else{
      if($char =~ m/[A-Za-z0-9_]/){
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
  
  #print "Parse String \n";
  
  my $quotes = chop($$message);
  
  while(length($$message)){
    my $char = chop($$message);
    
    if($char eq "\\"){
      #escaping just append the next char
      next;
    }
    
    #we hit the end of the string return to parent
    if($char eq $quotes){
      #print "parsed string: ".$string."\n";
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
  my $message = shift;
  
  my $number;
  my $char = chop($$message);
  my $point = 0;
  
  if($char =~ m/^[0-9|+|\-|\.]$/){
      $number .= $char;
      if($char eq "."){
        $point = 1;
      }
  }else{
    $self->{m_lastError} = "Invalid Begin of Number";
    return undef;
  }
  
  while(length($$message)){
    $char = chop($$message);
    if($char eq " "){
      last;
    }elsif(!$char =~ m/^[0-9|.]$/){
      $self->{m_lastError} = "Invalid Part of Number ".$char;
      return undef;
    }
    if($char eq '.'){ 
      if($point == 1){#only one point per number
        $self->{m_lastError} = "Numbers can only have one point";
        return undef;
      }else{
        $point = 1;
      }
    }
    $number .= $char;
  }
  #print "parsed number ".$number."\n";
  return $number;
}

1;
#package Test;

#print "Trying to parse: ".$ARGV[0];
#my $parser = Pms::Prot::Parser->new();
#$parser->parseMessage($ARGV[0]);
#if($parser->{m_lastError}){
#  print "\nDang ".$parser->{m_lastError}."\n";
#}
