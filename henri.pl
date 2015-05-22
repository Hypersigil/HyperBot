#!/usr/bin/perl

#
# Version 0.2.1a
# henri chain irc bot
# Modified from original source by 
# The HYPERSIGIL PROJECT
#
# formerly known as
# bubblez irc bot <3 by weekin2day
# based on dapper technology
# integrated with megahal
# 
# Modified 5/20/2015
# 

#use strict; # strict variables and references, doesnt compile
#use warnings; # Uncomment to see warnings

use Getopt::Std;

#use POE; # requires POE, apt-get install libpoe-perl
#use POE::Component::IRC; # IRC POE
use POE qw(Component::IRC);

use AI::MegaHAL; # requires AI-MegaHAL perl module
#use Megahal; # tried to use normal Megahal install to no avail

print("core_notice: Used modules initialized.\n");

getopts('n:r:i:s:p:c:h');

my @responses = ("hey:text:test");

my $VERSION = '0.2a';
my $NAME = 'henri';

my $irc;
my $megahal;

my $brainsave = 1;
my $brainpath = './';

# irc stuff
my $nickname;
my $realname;
my $ircname;
my $server;
my $port;
my @channels;
my $channels;

# text stuff
my $t_convert;

$nickname = $opt_n;
$realname = $opt_r;
$ircname = $opt_i;
$server = $opt_s;
$port = $opt_p;
$channels = $opt_c;

#$nickname |= ($NAME . $$ ); # orignal line, name + random number
$nickname |= ($NAME);
$realname |= $NAME . " " . $VERSION;
$ircname |= $NAME . " " . $VERSION;
$server |= "irc.hypersigil.org";
$port |= 6667;
$channels |= "#domus";

@channels = split(/ /, $channels);

# megahal # AI::MegaHAL or Megahal
$megahal = AI::MegaHAL->new('Path' => $brainpath, 'Prompt' => 0, 'Wrap' => 0, 'AutoSave' => $brainsave);

print("core_notice: Config Complete.\n");

#irc
print("core_notice: Spawn IRC Component.\n");
$irc = POE::Component::IRC->spawn();

# create poe session
POE::Session->create(
	package_states => [
         main => [ qw(
		_default 
		_start 
		irc_001 
		irc_public 

		) ],
     ],
	#inline_states => {
		#_start     => \&bot_start,
		#irc_001    => \&on_connect,
		#irc_public => \&on_public,
		#irc_disconnected => \&tryreconnect,
		#irc_error        => \&tryreconnect,
		#irc_socketerr    => \&tryreconnect,
		#autoping         => \&doping,

	#},
	heap => { irc => $irc }, # not used yet, need to implement
);

#sub bot_start
sub _start
{
	print("core_notice: Bot started.\n");
	$irc->yield(register => "all");

	$irc->yield(
		connect => {
			Nick     => $nickname,
			Username => $realname,
			Ircname  => $ircname,
			Server   => $server,
			Port     => $port,
			Raw      => 1,
		}
	);
}

#sub on_connect 
sub irc_001
{  
	print("core_notice: Connection established.\n");
	foreach (@channels) 
	{ 
		$irc->yield('join', $_ ); 
		print "Joining channel: $_ \n";
	} 
}

#sub doping
#sub irc_ping
sub thisisntworkingyet
{
	print("core_notice: Ping received: $_ \n"); 
	# is never called via first gen code??
	# tried to fix this

	$irc->yield(quote => 'PONG :hypersigil.org'); # try this
	my ( $kernel, $heap ) = @_[ KERNEL, HEAP ];

	$kernel->post( bot => userhost => $config->{nickname} )unless $heap->{seen_traffic};
	$heap->{seen_traffic} = 0;
	$kernel->delay( autoping => 200 );
}

sub tryreconnect #sub irc_disconnected
{
	print("core_notice: Try Reconnect?\n");
	my ( $kernel, $heap ) = @_[ KERNEL, HEAP ];

	$kernel->delay( autoping => undef );
	$kernel->delay( connect  => 15 );
}

#sub on_public
sub irc_public
{
	print("core_notice: On Public triggered.\n");
	$irc->yield(quote => 'PONG :hypersigil.org'); # this
	#$irc->yield('quote', 'PONG :hypersigil.org'); # or this?
	# these both work the same but idk if theyre helping

	my ($kernel, $who, $where, $msg) = @_[KERNEL, ARG0, ARG1, ARG2];
	my $nick    = (split /!/, $who)[0];
	
	my $channel = $where->[0];
	my $ts      = scalar localtime;
  
	my $hadnick = 0;
  
	if ($msg =~ /$nickname/) { $msg =~ s/$nickname //g; $msg =~ s/$nickname//g; $hadnick = 1; print("core_notice: Heard nickname?\n");}

	if ($msg =~ /^\.loadresponses/) { @responses = (); open FD, "brain.txt"; while (<FD>) { chomp; push @responses, $_; } close FD; }
	if ($msg =~ /^\.saveresponses/) { open FD, ">brain.txt"; foreach my $r (@responses) { print FD "$r\n"; } close (FD); }
  
	if (my ($msgstring) = $msg =~ /^\.addresponse (.*)/) { push @responses, $msgstring; return; }

	#if ($msg =~ /.time/) { $irc->yield(privmsg =>$channel, `date`); return; }
	#if ($msg =~ /.date/) { $irc->yield(privmsg =>$channel, `date`); return; }
  
	my @output = ();
	my $doresponse = 0;

	# must be language
  
	$megahal->learn($msg);
	print "String learned by MegaHAL.\n";
  
	AI::MegaHAL::megahal_cleanup();
  
	if ($hadnick)
	{
		print("core_notice: Heard nickname, responding!\n");
		foreach my $response (@responses)
	{

	# my ($m, $f, $v) = split(/:/, $response);

	if ($response =~ /(\S+)\:(\S+)\:(.*)/)
	{
		my $m=$1;
		my $f=$2;
		my $v=$3;
      
		if ($msg =~ /$m/) {
			if ($f eq "text")
			{
				push @output, $v;
				$doresponse=1;
			}
			if ($f eq "markov")
			{
				push @output, $megahal->do_reply($v);
				$doresponse=1;
			}
		}
	}
}
  
if ($doresponse)
{
	print "Force Response.\n";
	$irc->yield(privmsg => $channel, $output[rand @output]);
	return;
}
  
# everything else has failed # failed or passed? lol
print("core_notice: All checks passed: do_reply($msg)\n");

$t_convert = lc $megahal->do_reply($msg);

#$irc->yield(privmsg => $channel, $megahal->do_reply($msg));
$irc->yield(privmsg => $channel, $t_convert);
  
}
}
print("core_notice: Running POE Kernel.\n");
$poe_kernel->run();

sub _default {
	my ($event, $args) = @_[ARG0 .. $#_];
	my @output = ( "$event: " );

	for my $arg (@$args) {
		if ( ref $arg eq 'ARRAY' ) {
			push( @output, '[' . join(', ', @$arg ) . ']' );
		}
		else {
			push ( @output, "'$arg'" );
		}
	}
	print join ' ', @output, "\n";
	return;
 }

exit 0;