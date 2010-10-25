package Flickr;

use Modern::Perl;
use Moose;
use MooseX::FollowPBP;
use MooseX::Method::Signatures;

use HTTP::Lite;
use Encode::Base58;
use JSON;

has api_endpoint => (
    isa     => 'Str',
    is      => 'rw',
    default => 'http://api.flickr.com/services/rest/',
);
has api_key => (
    isa      => 'Str',
    is       => 'ro',
    required => 1,
);
has api_secret => (
    isa      => 'Str',
    is       => 'ro',
    required => 1,
);
has last_error => (
    isa => 'Maybe[Str]',
    is  => 'rw',
);



method get_photo ( Str $id! ) {
    my $info = $self->call_method(
            'photos.getInfo',
            'photo',
            {
                photo_id => $id,
            }
        );
    
    # add in the people in the photo
    my $people = $self->call_method(
            'photos.people.getList',
            'people',
            {
                photo_id => $id,
            }
        );
    $info->{'people'} = $people->{'person'}
        if defined $people->{'person'};
    
    return $self->repair_values_in_photo( $info )
        if defined $info;
    return;
}
method repair_values_in_photo ( HashRef $photo ) {
    $photo->{'comments'}    = $photo->{'comments'}{'_content'};
    $photo->{'description'} = $photo->{'description'}{'_content'};
    $photo->{'title'}       = $photo->{'title'}{'_content'};
    
    # rationalise tags into a more useful structure
    my @tags = @{ $photo->{'tags'}{'tag'} };
    delete $photo->{'tags'}{'tag'};
    
    foreach my $tag ( @tags ) {
        my $name = $tag->{'_content'};
        $photo->{'tags'}{ $name } = $tag;
        delete $photo->{'tags'}{ $name }{'_content'};
    }
    
    # rationalise urls into a more useful structure
    my @urls = @{ $photo->{'urls'}{'url'} };
    delete $photo->{'urls'}{'url'};
    
    foreach my $url ( @urls ) {
        my $type = $url->{'type'};
        $photo->{'urls'}{ $type } = $url->{'_content'};
    }
    
    # rationalise notes into a more useful structure
    my @notes = @{ $photo->{'notes'}{'note'} };
    $photo->{'notes'} = [];
    
    foreach my $note ( @notes ) {
        # TODO - work out this
        # (photo_216786678) from Pub Standards will help
        # use Data::Dumper::Concise;
        # print Dumper \$note;
        $note->{'text'} = $note->{'_content'};
        delete $note->{'_content'};
        
        push @{ $photo->{'notes'} }, $note;
    }
    
    # tweak the location structure
    foreach my $key ( keys %{ $photo->{'location'} } ) {
        my $place = $photo->{'location'}{ $key };
        if ( 'HASH' eq ref $place ) {
            $place->{'name'} = $place->{'_content'};
            delete $place->{'_content'};
        }
    }
    
    # add the photo image URLs
    $photo->{'urls'}{'photo_square'} = $self->photo_url( 'square',   $photo );
    $photo->{'urls'}{'photo_thumb'}  = $self->photo_url( 'thumb',    $photo );
    $photo->{'urls'}{'photo_small'}  = $self->photo_url( 'small',    $photo );
    $photo->{'urls'}{'photo_medium'} = $self->photo_url( 'medium',   $photo );
    $photo->{'urls'}{'photo_large'}  = $self->photo_url( 'large',    $photo );
    $photo->{'urls'}{'photo'}        = $self->photo_url( 'default',  $photo );
    $photo->{'urls'}{'photo_orig'}   = $self->photo_url( 'original', $photo )
        if defined $photo->{'originalsecret'};
    
    # add the short link
    $photo->{'urls'}{'short'} = $self->photo_short( $photo->{'id'} );
    
    return $photo;
}
method photo_url ( Str $size, HashRef $photo ) {
    my $url = sprintf( 
            'http://farm%s.static.flickr.com/%s/%s_',
            $photo->{'farm'},
            $photo->{'server'},
            $photo->{'id'}
        );
    
    my $secret  = $photo->{'secret'};
    my $osecret = $photo->{'originalsecret'};
    my $oformat = $photo->{'originalformat'};
    
    given ( $size ) {
        when ( 'square'   ) { $url .= "${secret}_s.jpg"; }
        when ( 'thumb'    ) { $url .= "${secret}_t.jpg"; }
        when ( 'small'    ) { $url .= "${secret}_m.jpg"; }
        when ( 'medium'   ) { $url .= "${secret}_z.jpg"; }
        when ( 'large'    ) { $url .= "${secret}_b.jpg"; }
        when ( 'original' ) { $url .= "${osecret}_o.${oformat}"; }
        default             { $url .= "${secret}.jpg"; }
    }
    
    return $url;
}
method photo_short ( Str $id ) {
    return sprintf(
            'http://flic.kr/p/%s',
            encode_base58( $id )
        );
}

method get_pool_photos ( Str $pool! ) {
    return $self->call_method(
            'groups.pools.getPhotos',
            'photos',
            {
                group_id => $pool,
            }
        );
}

method photos_search ( HashRef $args ) {
    # FIXME - paging of results instead of bludgeoning "lots of results"
    my $results = $self->call_method(
            'photos.search',
            'photos',
            {
                %$args,
                per_page => 500,
            }
        );
    
    return $results->{'photo'}
        if defined $results;
    return;
}

method call_method ( Str $method!, Str $value!, HashRef $args ) {
    $self->set_last_error();
    
    my $http  = HTTP::Lite->new();
    my $call  = URI->new( $self->get_api_endpoint() );
    my %form  = (
            format         => 'json',
            nojsoncallback => '1',
            api_key        => $self->get_api_key(),
            secret         => $self->get_api_secret(),
            method         => "flickr.${method}",
            %$args,
        );
    $call->query_form( \%form );
    
    my $code;
    while ( !defined $code ) {
        $code = $http->request( $call );
    }
    
    my $body = $http->body();
    my $data = from_json( $http->body() );
    
    # primitive rate limiting between calls
    select undef, undef, undef, 0.5;
    
    return $data->{ $value }
        if 'ok' eq $data->{'stat'};
    
    $self->set_last_error( "oh noes" );
    return;
}

1;
