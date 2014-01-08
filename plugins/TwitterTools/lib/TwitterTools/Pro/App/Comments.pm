package TwitterTools::Pro::App::Comments;
use strict;

#use TwitterTools::App::CMS;

sub twitter_share {
    my $app = shift;
	my $q = $app->param;
	my $plugin = MT->component('TwitterTools');
	my ($session, $commenter) = $app->get_commenter_session();
	my $access_token = $session->get('twitter_token');
	my $access_secret = $session->get('twitter_secret');
	return unless ($access_token && $access_secret);
    ## Send Twitter posts in the background.
#    MT::Util::start_background_task(
#        sub {
			my $client = _get_client($app);
		    $client->access_token($access_token);
		    $client->access_token_secret($access_secret);

			my $tweet = $q->param('status'); 
			my $res = $client->update({ status => $tweet });

			if ($res->{id}) {
			    #success
use Data::Dumper;
MT->log("res is:" . Dumper($res));
                return $res->{id};
			} else {
			    #error?
			}
#        }
#    );
}

sub _get_client {
	my ($app) = @_;
	my $q = $app->param;
	my $plugin = MT->component('TwitterCommenters');
	my $config = $plugin->get_config_hash('system');
	my $consumer_key = $config->{twitter_consumer_key} || MT->config('TwitterOAuthConsumerKey');
	my $consumer_secret = $config->{twitter_consumer_secret} || MT->config('TwitterOAuthConsumerSecret');
	use Net::Twitter::Lite::WithAPIv1_1;
	my $client = Net::Twitter::Lite::WithAPIv1_1->new(
		consumer_key    => $consumer_key,
		consumer_secret => $consumer_secret,
		ssl             => 1,
	);
	return $client;
}

sub twitter_account {
	my $app = shift;
	my $q = $app->param;
	my $plugin = MT->component('TwitterTools');
    my $author_id = $app->param('id')
        or return $app->error('Author id is required');
    my $user = MT->model('author')->load($author_id)
        or return $app->error('Author id is invalid');
    return $app->error('Not permitted to view')
        if $app->user->id != $author_id && !$app->user->is_superuser();
	my $profile;
	my $access_token;
	my $access_secret;
	my $twitter_username;
	my $authed = 0;
	if ($q->param('oauth_token')) {
		($profile, $access_token, $access_secret) = TwitterTools::App::CMS::_do_oauth_login($app);
		if ($profile) {
			$user->twitter_username($profile->{screen_name});
			$user->twitter_access_token($access_token);
			$user->twitter_access_secret($access_secret);
			$user->save;
		}
	} elsif ($q->param('start_oauth')) {
		my $args = {};
		$args->{id} = $user->id;
		return TwitterTools::App::CMS::_start_oauth_login($app,'twitter_account', $args);
	}
	if ($user->twitter_username && $user->twitter_access_token && $user->twitter_access_secret) {
		$twitter_username = $user->twitter_username;
		$authed = 1;
	}

	$app->build_page( $plugin->load_tmpl('twitter_account.tmpl'),
        {   return_url => $app->return_uri, 
	        id             => $user->id,
	        username       => $user->name,
	        edit_author_id => $user->id,
			authed		   => $authed,
			twitter_username => $twitter_username,
	  	} );
}


1;