package PubStandards;

use Modern::Perl;
use Moose;
use MooseX::FollowPBP;
use MooseX::Method::Signatures;

with 'PubStandards::Couch';

use Upcoming;
use Flickr;

use Config::Std;
use PubStandards::Chapter;
use Try::Tiny;

has upcoming => (
    isa     => 'Upcoming',
    is      => 'ro',
);
has flickr => (
    isa     => 'Flickr',
    is      => 'ro',
);
has config_file => (
    isa     => 'Str',
    is      => 'ro',
    default => 'pubstandards.conf',
);
has _config => (
    isa => 'HashRef',
    is  => 'rw',
);

method BUILD {
    $self->build_db_handle( 'pubstandards' );
    $self->{'_config'}  = $self->build_config();
    $self->{'upcoming'} = $self->build_upcoming();
    $self->{'flickr'}   = $self->build_flickr();
}
method build_config {
    my $file = $self->get_config_file();
    my %config;
    
    try {
        read_config $file => %config;
    }
    catch {
        warn "Couldn't read $file: $_";
    };
    
    return \%config;
}
method build_upcoming {
    my $api_key   = $self->get_config( 'upcoming', 'api_key' );
    my $api_token = $self->get_config( 'upcoming', 'api_token' );
    
    return Upcoming->new( api_key => $api_key, api_token => $api_token )
        if defined $api_key;
    
    warn "No Upcoming API key: cannot initialise.";
    return;
}
method build_flickr {
    my $api_key    = $self->get_config( 'flickr', 'api_key' );
    my $api_secret = $self->get_config( 'flickr', 'api_secret' );
    
    return Flickr->new( api_key => $api_key, api_secret => $api_secret )
        if defined $api_key && $api_secret;
    
    warn "No Flickr API key or secret: cannot initialise.";
    return;
}


method get_chapter ( Str $chapter ) {
    return PubStandards::Chapter->new(
            name   => $chapter,
            parent => $self,
        );
}

method get_event_photos_from_flickr ( Str $id! ) {
    my $flickr = $self->get_flickr();
    my %event_photos = (
            machine_tags     => "upcoming:event=${id}",
            machine_tag_mode => 'any',
        );
    
    $flickr->photos_search( \%event_photos );
}
method get_photo_details ( Str $id! ) {
    my $flickr = $self->get_flickr();
    $flickr->get_photo( $id );
}

method get_config ( Str $section!, Str $key? ) {
    return $self->{'_config'}{ $section }{ $key }
        if defined $key;
        
    return $self->{'_config'}{ $section };
}

1;
