package PubStandards::Views;

use Modern::Perl;
use Moose::Role;
use MooseX::Method::Signatures;

use Encode;
use Lingua::EN::Numbers::Ordinate;
use Text::Intermixed;

method handle_view ( $request! ) {
    $self->set_request( $request );
    my $path = $request->path();
    
    say '';
    say "-> $path";
    
    given ( $path ) {
        when ( '/' ) {
            return $self->render_homepage();
        }
        when ( '/previously' ) {
            return $self->render_events_list();
        }
        when ( '/people/' ) {
            return $self->render_people_list();
        }
        when ( '/photo/' ) {
            return $self->render_redirect( '/' );
        }
        when ( m{^ /next (\.ics)? $}x ) {
            my $ics = $1;
            return $self->render_calendar( $ics );
        }
        when ( m{^ /photo/ ( [a-z0-9_-]+ ) $}x ) {
            my $id = $1;
            return $self->render_photo( $id );
        }
        when ( m{^ /people/ ( [a-z0-9_-]+ ) $}x ) {
            my $name = $1;
            return $self->render_person( $name );
        }
        when ( m{^ / ( [a-z0-9_-]+ ) $}x ) {
            my $slug = $1;
            my $doc  = $self->get_document_by_slug( $slug );
            
            if ( defined $doc ) {
                my $id = $doc->{'id'};
                $id =~ m{^ ( [a-z]+ ) _ ( \d+ ) $}x;
                
                my $view    = $1;
                my $item_id = $2;
                
                return $self->render_event( $item_id )
                    if 'event' eq $view;
            }
        }
    }
    
    return $self->render_404();
}

method render_homepage {
    my $template = $self->get_template( 'homepage' );
    my $future   = $self->get_future_events();
    
    foreach my $event ( @$future ) {
        if ( $event->{'doc'}{'start_date'} =~ m{ (\d+) - (\d+) - (\d+) }x ) {
            $event->{'doc'}{'year'}  = $1;
            $event->{'doc'}{'month'} = $self->get_name_for_month( int $2 );
            $event->{'doc'}{'day'}   = ordinate $3;
        }
    }
    
    my %data = (
            days_remaining  => 5,
            hours_remaining => 8,
            next_timestamp  => 1287075600,
            photos          => $self->get_sample_photos(),
            future_events   => $future,
        );
    
    return $self->render_html_response( $template, \%data );
}
method render_events_list {
    my $template = $self->get_template( 'all_events' );
    my %data     = (
            events => $self->get_all_events(),
        );
    
    return $self->render_html_response( $template, \%data );
}
method render_event ( $id ) {
    my $template = $self->get_template( 'event' );
    my $doc      = $self->get_document( "event_${id}" );
    my %data     = (
            %$doc,
            photos => $self->get_photos_from_event( $id ),
        );
    
    return $self->render_html_response( $template, \%data );
}
method render_people_list {
    my $template = $self->get_template( 'all_people' );
    my %data     = (
            people => $self->get_all_people(),
        );
    
    return $self->render_html_response( $template, \%data );
}
method render_person ( $name ) {
    my $ps       = $self->get_parent();
    my $doc      = $ps->get_document( "person_$name" );
    
    if ( defined $doc ) {
        my $template = $self->get_template( 'person' );
        
        # TODO - events appeared at
        $doc->{'photos'} = $self->get_photos_of_person( $doc->{'nsid'} );
        
        return $self->render_html_response( $template, $doc )
    }
    
    return $self->render_404();
}
method render_photo ( $photo ) {
    my $ps  = $self->get_parent();
    my $doc = $ps->get_document( "photo_${photo}" );
    
    if ( defined $doc ) {
        my $template = $self->get_template( 'photo' );
        
        $doc->{'event'} = $ps->get_document( $doc->{'event_document'} );
        
        foreach my $person ( @{ $doc->{'people'} } ) {
            my $id   = $person->{'username'};
            my $pdoc = $ps->get_document( "person_${id}" );
            
            push( @{ $doc->{'users'} }, $pdoc )
                if defined $pdoc;
        }
        
        return $self->render_html_response( $template, $doc );
    }
    
    return $self->render_404();
}
method render_calendar ( $is_ics? ) {
    my $type     = defined $is_ics ? 'ics' : 'html';
    my $template = $self->get_template( 'calendar', $type );
    
    my $ps      = $self->get_parent();
    my @dates   = $ps->get_year_of_pubstandards_dates();
    my $has_url = 1;
    
    my @list_of_dates = map {
            my %hash = (
                    stamp    => $_,
                    day      => (localtime $_)[3],
                    ordinate => ordinate( (localtime $_)[3] ),
                    month    => (localtime $_)[4]+1,
                    year     => (localtime $_)[5]+1900,
                    name     => $self->get_canonical_event_name( $_ ),
                );
            
            my $event = $self->get_event_by_date( $_ );
            $hash{'url'} = 'http://upcoming.yahoo.com/event/'
                           . $event->{'doc'}{'id'}
                if defined $event;
            
            
            \%hash;
        } @dates;
    
    return $self->render_ics_response(
            $template,
            {
                dates => \@list_of_dates,
            }
        ) if $is_ics;
    
    return $self->render_html_response(
            $template,
            {
                dates  => \@list_of_dates,
            }
        );
}
method render_404 () {
    my $template = $self->get_template( '404' );
    return $self->render_html_response( $template, {}, 404 );
}
method render_redirect ( Str $path ) {
    return [
            301,
            [
                'Location' => $path,
            ],
            [],
        ];
}
method render_html_response ( $template, $data, $code=200 ) {
    my $headers = [ 'Content-Type' => 'text/html; charset=UTF-8' ];
    return $self->render_response( $template, $data, $headers, $code );
}
method render_ics_response ( $template, $data, $code=200 ) {
    my $headers = [ 'Content-Type' => 'text/html; charset=UTF-8' ];
    my $request = $self->get_request();
    my %data    = (
            request => $request,
            chapter => $self->get_name(),
            %$data,
        );
    
    my( $output, $errors ) = render_intermixed( $template, \%data );
    # TODO - deal with errors appropriately
    
    $output =~ s{\n}{\r\n}gs;       # because the spec says so
    
    return [
            $code,
            $headers,
            [
                encode_utf8( $output ),
            ]
        ];
}
method render_response ( $template, $data, $headers, $code=200 ) {
    my $request = $self->get_request();
    my %data    = (
            request           => $request,
            chapter           => $self->get_name(),
            flickr_group      => $self->get_flickr_group(),
            flickr_group_name => $self->get_flickr_group_name(),
            %$data,
        );

    my( $output, $errors ) = render_intermixed( $template, \%data );
    # TODO - deal with errors appropriately
    
    return [
            $code,
            $headers,
            [
                encode_utf8( $output ),
            ]
        ];
}

1;
