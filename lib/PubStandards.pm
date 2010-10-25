package PubStandards;

use Modern::Perl;
use Moose;
use MooseX::FollowPBP;
use MooseX::Method::Signatures;

with 'PubStandards::Couch';

use Upcoming;

use Config::Std;
use PubStandards::Chapter;
use Try::Tiny;

has upcoming => (
    isa     => 'Upcoming',
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

method get_chapter ( Str $chapter ) {
    return PubStandards::Chapter->new(
            name   => $chapter,
            parent => $self,
        );
}

method get_config ( Str $section!, Str $key? ) {
    return $self->{'_config'}{ $section }{ $key }
        if defined $key;
        
    return $self->{'_config'}{ $section };
}

1;
