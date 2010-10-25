#!/usr/bin/env perl

use Modern::Perl;

use Plack::App::Cascade;
use Plack::App::File;
use Plack::Request;
use Plack::Builder;

use Encode;
use IO::All;
use PubStandards;



my $ps = PubStandards->new();

my $static_content  = Plack::App::File->new( root => 'site' )->to_app;
my $dynamic_content = sub {
    my $env     = shift;
    my $request = Plack::Request->new( $env );
    my $name    = $ps->get_chapter_from_env( $env );
    my $chapter = $ps->get_chapter( $name );
    
    return $chapter->handle_view( $request );
};

# serve up static files by preference if they exist
my $cascade = Plack::App::Cascade->new();
$cascade->add( $static_content );
$cascade->add( $dynamic_content );

# run the web site
$cascade->to_app;
