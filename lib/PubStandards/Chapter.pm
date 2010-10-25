package PubStandards::Chapter;

use Modern::Perl;
use Moose;
use MooseX::FollowPBP;
use MooseX::Method::Signatures;

with 'PubStandards::Couch';
with 'PubStandards::Views';

use Text::SimpleTemplate;

use constant CONFIG_KEYS => qw(
    flickr_group
    flickr_group_name
    upcoming_group
);

has parent => (
    isa => 'PubStandards',
    is  => 'ro',
);
has name => (
    isa => 'Str',
    is  => 'ro',
);
has flickr_group => (
    isa     => 'Str',
    is      => 'ro',
    default => 0,
);
has flickr_group_name => (
    isa     => 'Str',
    is      => 'ro',
);
has request => (
    isa => 'Plack::Request',
    is  => 'rw',
);
has templates => (
    isa     => 'Text::SimpleTemplate',
    is      => 'ro',
);
has upcoming_group => (
    isa     => 'Str',
    is      => 'ro',
    default => 0,
);
method build_templates {
    my $chapter   = $self->get_name();
    my $templates = Text::SimpleTemplate->new(
            base_dir  => 'templates',
            dimension => $chapter,
        );
    
    return $templates;
}
method BUILD {
    my $name = $self->get_name();
    
    $self->build_db_handle( "pubstandards" );
    
    my $parent = $self->get_parent();
    my $db     = $parent->get_database();
    my $doc    = $db->get_doc( $name );
    
    return
        if defined $doc->{'error'} && ( 'not_found' eq $doc->{'error'} );
    
    foreach my $key ( CONFIG_KEYS ) {
        $self->{ $key } = $doc->{ $key };
    }
    
    $self->{'templates'} = $self->build_templates();
}



method get_all_events {
    my $ps = $self->get_parent();
    
    my( $results, $more ) = $ps->query_view(
            $self->get_name(),
            'events',
            {
                limit    => 100,
            }
        );
    
    return $results->{'data'};
}
method get_future_events {
    my $ps    = $self->get_parent();
    my @now   = localtime();
    my @dates = ( $now[5]+1900, $now[4]+1, $now[3] );
    my $key   = '[' 
              . join( ',', @dates ) 
              . ']';
    
    my( $results, $more ) = $ps->query_view(
            $self->get_name(),
            'events',
            {
                include_docs => 'true',
                limit        => 100,
                startkey     => $key,
            }
        );
    
    return $results->{'data'};
}
method get_all_people {
    my $ps = $self->get_parent();
    
    my( $results, $more ) = $ps->query_view(
            $self->get_name(),
            'people',
            {
                limit        => 100,
                include_docs => 'true',
            }
        );
    
    return $results->{'data'};
}

method get_sample_photos {
    my @photos;
    
    # get photos from four random sets
    foreach my $i ( 1..4 ) {
        my $key = sprintf '%02d', int rand 100;
        push @photos, $self->get_photos_by_fragment_id( $key );
    }
    
    return \@photos;
}
method get_photos_by_fragment_id ( Str $id! ) {
    my( $results, $more ) = $self->query_view(
            $self->get_name(),
            'photo_by_id_fragment',
            {
                include_docs => 'true',
                key          => qq("${id}"),
                limit        => 9,
            }
        );
    
    return @{ $results->{'data'} };
}
method get_all_events_from_upcoming {
    my @events;
    
    push @events, @{ $self->get_past_events_from_upcoming() };
    push @events, @{ $self->get_future_events_from_upcoming() };
    
    return \@events;
}
method get_past_events_from_upcoming {
    my $group    = $self->get_upcoming_group();
    my $parent   = $self->get_parent();
    my $upcoming = $parent->get_upcoming();
    
    return $upcoming->group_get_events( id => $group, show_past => 1 );
    
}
method get_future_events_from_upcoming {
    my $group    = $self->get_upcoming_group();
    my $parent   = $self->get_parent();
    my $upcoming = $parent->get_upcoming();
    
    return $upcoming->group_get_events( id => $group );
}
method get_template ( Str $template!, Str $type='html' ) {
    my $templates = $self->get_templates();
    return $templates->get_template( $template, $type );
}

method get_name_for_month ( Int $month ) {
    my $ps = $self->get_parent();
    return $ps->get_name_for_month( $month );
}


1;
