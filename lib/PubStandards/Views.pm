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
method render_404 () {
    my $template = $self->get_template( '404' );
    return $self->render_html_response( $template, {}, 404 );
}
method render_html_response ( $template, $data, $code=200 ) {
    my $headers = [ 'Content-Type' => 'text/html; charset=UTF-8' ];
    return $self->render_response( $template, $data, $headers, $code );
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
