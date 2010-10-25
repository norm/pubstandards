package PubStandards::Chapter;

use Modern::Perl;
use Moose;
use MooseX::FollowPBP;
use MooseX::Method::Signatures;

with 'PubStandards::Couch';

use constant CONFIG_KEYS => qw(
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
has upcoming_group => (
    isa     => 'Str',
    is      => 'ro',
    default => 0,
);
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
1;
