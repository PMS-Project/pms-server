#!/usr/bin/perl -w 

=begin nd
  
  Package: Pms::Prot::Netstring

  Package handles parsing and validation
  of netstrings which is the stream protocol 
  we use for PMS.
  
  A Netstring looks like that:
  *10:abcdefghij,*
  
  [len]:[string],
  
  A better documentation can be found at: http://cr.yp.to/proto/netstrings.txt

=cut

package Pms::Prot::Netstring;

use strict;
use utf8;
no bytes;

use Data::Dumper;


our $Debug = $ENV{'PMS_DEBUG'};
our $lastError;

=begin nd
  Function: parse
    Tries to parse a nestring from the buffer.
    When it can read a netrstring, the data is removed from
    the buffer.
  
  Access:
    Public
    
  Parameters:
    $handle - the AnyEvent::Handle
    $buffer - the read Buffer
    
  Returns:
    undef  - if it could not read a netstring
    string - the data that was read from the buffer
=cut
sub parse {
  my $handle = shift;
  my $buffer = shift;
  
  if(!length($$buffer)){
    return undef;
  }
  
  $lastError = undef;
  
  #TODO this will fail if we got only the first few numbers of the netstring
  #but did not receive the delimiter
  #warn $$buffer;
  #warn " buffer len: ".length($$buffer);
  if($$buffer =~ m/^[0-9]+:/){
    my $delim = index($$buffer,':');
    if($delim < 0){
      #warn "No delim";
      return undef;
    }
    
    my $len = substr($$buffer,0,$delim); #copy length from buffer
    #warn "Read len: ".$len;
    #warn "netstring len: ".($len+$delim+1+1)." buffer len: ".length($$buffer);
    if(length($$buffer) < ($len+$delim+1+1)){
      #warn "Too short";
      return undef; #not enough data
    }
    
    substr($$buffer,0,$delim+1,'');  #remove length and : from the beginning
    my $value = substr($$buffer,0,$len,''); #remove data from the buffer
    if(substr($$buffer,0,1,'') ne ','){ #check for last character to be a ,
      #warn "Error";
      $lastError = "Invalid Netstring";
      return undef;
    }
      
    #warn "Received Netstring ".$value."\n";
    return $value;
  }
  #warn "Regexp missed";
  $lastError = "Invalid Netstring";
  return undef;
}

=begin nd
  Function: serialize
    Serializes a message into the netstring format
  
  Access:
    Public
    
  Parameters:
    $value - the data we want to serialize
    
  Returns:
    string - the message in netrstring format
=cut
sub serialize {
  my $value = shift;
  
  my $netstring = length($value).":".$value.","; 
  if($Debug){
    warn "PMS-Core> ". "Sending netstring: ".$netstring;
  }
  return $netstring;
}

1;