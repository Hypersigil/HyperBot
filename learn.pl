#!/usr/bin/perl

#
# Miriyázha Crawler Brain Builder
# Modified from original source by 
# The HYPERSIGIL PROJECT
#
# Modified 5/23/2015
# 

# Options
my $brainfile;
my $filename ;
my $recursion;


$filename  = 'brainlist.txt';
$recursion = 1;
$brainfile = './';



#
# Constructors
#
use Getopt::Std;
use AI::MegaHAL;
use URI;
use HTML::Strip;
use WWW::Mechanize;
require URI::Find;
use HTML::LinkExtractor;
use LWP::Simple qw($ua head);

my $htmlstrip = HTML::Strip->new();
my $mech = WWW::Mechanize->new();
my $uri_finder = URI::Find->new(\&callback);
$mech->agent("Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/42.0.2311.152 Safari/537.36");
my $LX = new HTML::LinkExtractor();
$megahal = AI::MegaHAL->new('Path' => $brainfile, 'Prompt' => 0, 'Wrap' => 0, 'AutoSave' => 1);

open(my $fh, '<:encoding(UTF-8)', $filename)
  or die "Could not open file '$filename' $!";
  
while (my $row = <$fh>) {
  chomp $row;
  learn($row);
}
  
  print STDOUT "Completed recursive run";



  
  
  sub learn{
	print STDOUT "Called learn\n\n";
	$msg = $_[0];
	$uri_finder->find(\$msg);
    $megahal->learn($htmlstrip->parse($msg));
  }
  
  sub callback
  {
	my $url = $_[0];
	print STDOUT "Calback: $url \n\n";
	recurse_html($url,$recursion);
  }
  
  
sub testurl{
  my $ok = FALSE;
  my $turl = lc($_[0]);
  if($turl =~ /.*reddit.*/){ $ok = TRUE; };
  if($turl =~ /.*\.jpg$/){ $ok = TRUE; };
  if($turl =~ /.*\.css$/){ $ok = TRUE; };
  if($turl =~ /.*\.js$/){ $ok = TRUE; };
  if($turl =~ /.*\.jpeg$/){ $ok = TRUE; };
  if($turl =~ /.*\.gif$/){ $ok = TRUE; };
  if($turl =~ /.*\.png$/){ $ok = TRUE; };
  if($turl =~ /.*\.zip$/){ $ok = TRUE; };
  if($turl =~ /.*\.pdf$/){ $ok = TRUE; };
  if($turl !~ /^http.*$/){ $ok = TRUE; };
  if($ok eq TRUE) { print STDOUT 'Failed test\n\n'; } else{ print STDOUT "Test ok\n\n";}
  return $ok;
}

# takes a URL, retrieves page, strips out HTML, feeds content to MegaHAL
sub strip_html
{
  if(testurl($_[0]) eq TRUE) { print STDOUT "fail test"; return; }
  print STDOUT "Reading: ";
  my $url = $_[0];
  print STDOUT $url;
  print STDOUT "\n";
  #anti MRA-bot

  if($url ne ''){
	if(head($url)){
		print STDOUT "Got URL\n\n";
		$mech->get($url) or return;
		$megahal->learn($htmlstrip->parse($mech->content()));
		AI::MegaHAL::megahal_cleanup();
	print STDOUT $htmlstrip->parse($mech->content());
	}
  }
}

sub recurse_html
{
  print STDOUT "Recurse called: ".$_[0]." ".$_[1]."\n\n";
  if(testurl($_[0]) eq TRUE ) { print STDOUT "fail test"; return; }
  print STDOUT "Recursive Reading: ";
  my $url = $_[0];
  print STDOUT "$url\n\n";
  
  if(head($url)){
	print STDOUT "Got URL\n\n";
	$mech->get($url) or return;
	my $content = $mech->content();
	$LX->parse(\$content);

	my $rdepth = $_[1];
	my $rdminus = $rdepth - 1;
	for my $Link( @{ $LX->links } ) {
		my $tempurl = $$Link{href};
		print STDOUT "TempURL: $tempurl\n";
		if($tempurl =~ /^http.*/){
			print STDOUT "Found absolute\n\n";
			if(head($tempurl)){
				if($rdepth gt 0){	
					recurse_html($tempurl,$rdminus);
				}else{
					strip_html($tempurl);
				}
			}
		}else{
			my $uri = URI->new_abs($tempurl,$url);
			print STDOUT "Found relative: ".$uri->canonical."\n\n";
			if(head($uri->canonical)){
				strip_html($uri->canonical);
			}
		}
	}
	$megahal->learn($htmlstrip->parse($content));
	print STDOUT $content;
    AI::MegaHAL::megahal_cleanup();
	print STDOUT "Done reading\n\n";
  }
}


exit 0;
