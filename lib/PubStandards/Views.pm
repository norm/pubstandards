package PubStandards::Views;

use Modern::Perl;
use Moose::Role;
use MooseX::Method::Signatures;

use Encode;
use Text::Intermixed;

method handle_view ( $request! ) {
    return $self->render_404();
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
