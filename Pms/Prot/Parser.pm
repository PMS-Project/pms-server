#!/usr/bin/perl -w
=begin nd

  Package: Pms::Prot::Parser
  
  Description:
  
  This Package implements the Parser for our command syntax
  that is used to communicate between the server and the clients.
  
  Protocol explained:
  
  Every Request to the Server has the same look
  
  :/command arg1 arg2 arg3
  
  - All arguments are seperated by whitespaces
  
  - A *command-name* has to be a TOKEN which means it *has* to start with a letter
    followed by upper and lower case letters and numbers.
  
  - A Argument can either be a *string* or a *number*.
  
  - A *string* always havo to start with quotes " or ' and end with the same.
    Every quote in the string needs to be escaped.
  
  - A *number* can start with +,-, . or a number

=cut

package Pms::Prot::Parser;
use strict;

=begin nd
  Constructor: new
  Initializes the Object , no arguments
=cut
sub new{
  my $class = shift;
  my $self = {};
  bless($self,$class);
  
  $self->{m_lastError} = undef;
  
  return $self;
}


=begin nd
  Function: parseMessage
  
  Takes the buffer and tries to read a command with all arguments out of it.
  
  If a error happened it will return undef and set the m_lastError member
  which can be directly accessed from the caller.
  
  (start code)
  my %command = $parser->parseMessage($buffer);
  if($command != undef){
      print "CommandName: ".$$command{command};
  }
  (end)
  
  Access: 
    Public
  
  Parameters:
    buffer - The buffer that contains the message
    
  Returns:
    *undef* in case of a error
    
    or a *hash* containing the name and the arguments for the command 
    that needs to get called.
=cut 
sub parseMessage (){
  my $self = shift;
  my $string = shift;
  my $message;
  
  #reverse string so we can always grab the last character
  $message = reverse $string;
  
  my $char = chop($message);
  if($char ne "/"){
    $self->{m_lastError} = "First element of message has to be a /";
    return undef; #error
  }
  
  #first we need a token , its the command name
  my $name = $self->_parseToken(\$message);
  if(!defined $name){
    return undef; #error
  }
  
  my @arguments;
  while(1){
    _consumeWhitespace(\$message);
    if(!length($message)){
      last;
    }
    
    #print "remaining message: '".$message."'\n";
    
    #don't cut the first element out so the subparser can read it
    my $char = substr($message,length($message)-1,1);
    #print "Next Char: '".$char."'\n";
    my $arg  = undef;
    if($char eq "\"" || $char eq "'"){
      $arg = $self->_parseString(\$message);
    }elsif($char =~ m/^[0-9|+|\-|\.]$/){ #a number can start with 0-9 + - or a . 
      $arg = $self->_parseNumber(\$message);
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

=begin nd

  Function: _consumeWhitespace
  cuts all whitespaces from the beginning of the buffer
  
  Access: 
    Private
  
  Parameters:
    $buffer - The buffer that contains the message
=cut
sub _consumeWhitespace(){
  my $message = shift;
  $$message =~ s/\s+$//; #remove leading spaces
}


=begin nd
  Function: _parseToken
    Tries to read a Token from the buffer and returns it
  
  Access:
    Private
    
  Parameters:
    $buffer - the current read buffer
    
  Returns:
    The token or undef if a error happened
=cut
sub _parseToken (){
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

=begin nd
  Function: _parseString
    Tries to read a string from the buffer and returns it
  
  Access:
    Private
    
  Parameters:
    $buffer - the current read buffer
    
  Returns:
    The string or undef if a error happened
=cut
sub _parseString (){
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

=begin nd
  Function: _parseNumber
    Tries to read a number from the buffer and returns it
  
  Access:
    Private
    
  Parameters:
    $buffer - the current read buffer
    
  Returns:
    The number or undef if a error happened
=cut
sub _parseNumber (){
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
