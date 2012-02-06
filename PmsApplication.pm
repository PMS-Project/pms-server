#!/usr/bin/perl -w

package PmsApplication;

use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;
use EventHandler;


sub new (){
  my $class = shift;
  my $self  = {};

  bless ($self, $class);

  $self->{m_eventLoop}     = AnyEvent->condvar();
  $self->{m_signalHandler} = AnyEvent->signal (
			      signal => "TERM", 
			      cb => sub {
				warn "Received TERM Signal\n";
				$self{m_eventLoop}->send; #Exit from Eventloop
			      });
  $self->{m_timers}   = ();
  $self->{m_events}   = EventHandler->new();
  $self->{m_clients}  = ();
  
  $self->{m_listeningSocket} = 	tcp_server(undef, 8888, $self->_createNewConnectionCallback());

  $self->connectEvent(client_connected => sub{  warn "Client Connected Slot 1";}
		     ,client_connected => sub{  warn "Client Connected Slot 2";});
  
  return $self;
}

sub execute (){
  my $self = shift;
  $self->{m_eventLoop} ->recv; #eventloop
}

sub loadModules (){
  
}

sub connectEvent (){
  my $self = shift;

  return $self->{m_events}->reg_cb(@_);
}

sub disconnect (){
  $self = shift;
  $guard = shift;
  
  $self->{m_events}->unreg_cb($guard);
}

sub _createNewConnectionCallback(){
  my $self = shift;

  return sub{
    my ($fh, $host, $port) = @_;
  
    if(defined $self->{m_eventLoop}){
      warn "EventLoop is Defined";
    }

    if(defined $self->{m_signalHandler}){
      warn "m_signalHandler is Defined";
    }

    if(defined $self->{m_listeningSocket}){
      warn "m_listeningSocket is Defined";
    }

    warn "Incoming Connection";
    if(defined $self->{m_events}){
      $self->{m_events}->event(client_connected);
    }else{
      warn "Object is nicht definiert";
    }

    #TODO check host and port
    $self->{m_clients}{$fh} = new AnyEvent::Handle(
			      fh     => $fh,
			      on_error => sub {
				warn "error $_[2]";
				$_[0]->destroy;
			      },
			      on_eof => sub {
				$_[0]->destroy; # destroy handle
				warn "Other Side disconnected.";
			      });
		    
    my @start_request; @start_request = (line => sub {
	my ($hdl, $line) = @_;

	warn "Something happend";
	warn ($line);

	warn "Clients Connected".keys(%{$self->{m_clients}});

	
	foreach my $k (keys %{$self->{m_clients}}){
	  warn "Key: ".$k;
	  if($k ne $hdl->fh()){
	      if(defined($self->{m_clients}{$k})){
		  $self->{m_clients}{$k}->push_write($line);
	      }
	  }
	}

	# push next request read, possibly from a nested callback
	warn "Pushing new Read Request";
	$hdl->push_read(@start_request);
    }); 
    $self->{m_clients}{$fh}->push_read(@start_request);
  }
}
1;