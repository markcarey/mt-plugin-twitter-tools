package TwitterTools::Pro::App::CMS;
use strict;

use TwitterTools::App::CMS;

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