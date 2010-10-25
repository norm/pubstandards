package Upcoming;

use Modern::Perl;
use Moose;
use MooseX::FollowPBP;
use MooseX::Method::Signatures;

use HTTP::Lite;
use JSON;
use URI;
use XML::Simple;

use constant GET  => 0;
use constant POST => 1;

has api_endpoint => (
    isa     => 'Str',
    is      => 'rw',
    default => 'http://upcoming.yahooapis.com/services/rest/',
);
has api_key => (
    isa      => 'Str',
    is       => 'ro',
    required => 1,
);
has api_token => (
    isa => 'Str',
    is  => 'rw',
);
has last_error => (
    isa => 'Maybe[Str]',
    is  => 'rw',
);



method group_get_events (
    Str  :$id,
    Bool :$show_past = 0,
    Bool :$desc      = 0,
    Bool :$added     = 0,
    Int  :$per_page  = 0,
    Int  :$page      = 1
) {
    my %args = (
            group_id  => $id,
            show_past => $show_past,
        );
    
    $args{'eventsPerPage'} = $per_page
        if $per_page;
    $args{'page'} = $page
        if $per_page;
    $args{'dir'} = 'desc'
        if $desc;
    $args{'order'} = 'time_added'
        if $added;
    
    return $self->call_method( 'group.getEvents', 'event', GET, \%args );
}

method get_auth_token {
    my $key = $self->get_api_key();
    my $url = "http://upcoming.yahoo.com/services/auth/?api_key=${key}";
    
    say "Authorise here:\n$url";
    say "\nThen enter the code displayed:";
    my $frob = <>;
    chomp $frob;
    
    my $result = $self->call_method( 
                     'auth.getToken',
                     'token',
                     GET,
                     { frob => $frob }
                 );
                 
    say "TOKEN: " . $result->{'token'}
        if defined $result;
}

method call_method (
    Str     $method!,
    Str     $value!,
    Bool    $is_post = 0,
    HashRef $args
) {
    $self->set_last_error();
    
    my $http  = HTTP::Lite->new();
    my $call  = URI->new( $self->get_api_endpoint() );
    my $token = $self->get_api_token();
    my %form  = (
            api_key => $self->get_api_key(),
            method  => $method,
            format  => 'json',
            %$args,
        );
    
    $form{'token'} = $token
        if defined $token;
    
    my $code;
    my $data;
    if ( $is_post ) {
        $http->prepare_post( \%form );
        $code = $http->request( $call );
    }
    else {
        $call->query_form( \%form );
        $code = $http->request( $call );
    }
    
    my $body = $http->body();
    
    if ( '{' eq substr $body, 0, 1 ) {
        $data = from_json( $http->body() );
        $data = $data->{'rsp'};
    }
    else {
        $data = XMLin( $http->body() );
    }
    
    if ( 'fail' eq $data->{'stat'} ) {
        say "-> FAIL";
        use Data::Dumper::Concise;
        print Dumper $data;
        
        $self->set_last_error( $data->{'msg'} );
        return;
    }
    
    return $data->{ $value };
}

1;
