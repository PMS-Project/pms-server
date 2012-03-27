#!/usr/bin/perl -w 
=begin nd
  
  Package: Pms::Prot::WebSocket::Protocol

  Package handles parsing and validation
  of netstrings which is the stream protocol 
  we use for PMS.
  
  A Netstring looks like that:
  *10:abcdefghij,*
  
  [len]:[string],
  
  A better documentation can be found at: http://cr.yp.to/proto/netstrings.txt
  
  To use the code in the Package it just has to be imported. It will automatically
  register read and write functions to AnyEvent::Handle so we don't have to care
  about how the Handles internally read the Packages from the Socket.
  That makes it easy to plug in another Protocol easily.
  
  All Functions are private.

=cut

package Pms::Prot::WebSocket::Protocol;

use strict;
use Protocol::WebSocket::Handshake::Server;
use Protocol::WebSocket::Frame;
use AnyEvent::Handle;


sub _parseNetString {
  my $handle = shift;
  my $buffer = \$handle->{pmsReadBuf};
  
  if(!length($$buffer)){
    return undef;
  }
  
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
      $handle->{pmsReadError} = "Invalid Netstring";
      return undef;
    }
      
    #warn "Received Netstring ".$value."\n";
    return $value;
  }
  #warn "Regexp missed";
  $handle->{pmsReadError} = "Invalid Netstring";
  return undef;
}

sub _netstringify {
  my $value = shift;
  my $netstring = length($value).":".$value.","; 
  warn "Sending netstring: ".$netstring;
  return $netstring;
}

AnyEvent::Handle::register_read_type websock_pms => sub{
  my $hdl = shift;
  my $cb  = shift;
  
  sub{
    
    my $chunk = $hdl->{rbuf};
    if(!defined $chunk){
      return;
    }
    
    #warn "Message";
    
    $hdl->{rbuf} = undef;
    my $hs    = $hdl->{pmsWebSockSrv};
    my $frame = $hdl->{pmsWebSockFrame};
    if(!defined $hs){
      $hdl->{pmsWebSockSrv} = $hs = Protocol::WebSocket::Handshake::Server->new();
      $hdl->{pmsWebSockFrame} = $frame = Protocol::WebSocket::Frame->new();
    }
    
    $hdl->{pmsReadError} = undef; #remove last error
  
    if (!$hs->is_done) {
      #this will append to its internal buffer until handshake is done
      $hs->parse($chunk);
    
      if ($hs->is_done) {
        #warn "Handshake done";
        $hdl->push_write($hs->to_string);
      }
      return undef;
    }
    
    
    #If we enter this Path the handshake is done and we can read the Frame
    $frame->append($chunk);
    my $has_read_data = 0;
    while (my $message = $frame->next) {
      $hdl->{pmsReadBuf} .= $message;
      $has_read_data = 1;
    }
    
    if(!$has_read_data){
      return;
    }
    
    #warn "Frames found";
    
    my $value = _parseNetString($hdl);
    if(defined $value){
      #warn "Callback";
      $cb->($hdl,$value);
      return 1; #tell the AnyEvent::Handle code that we finally have read data
    }else{
      if(defined $hdl->{pmsReadError}){
         $_[0]->_error (Errno::EBADMSG);
      }
    }
  }
};

AnyEvent::Handle::register_write_type websock_pms => sub {
  warn "Writing Websocket";
  my $handle = shift;
  my $frame  = Protocol::WebSocket::Frame->new(_netstringify(shift));
  $handle->push_write($frame->to_bytes);
};

1;