package TwitterTools::App::CMS;
use strict;

# use MT::Util qw( dirify );
use TwitterTools::Util qw( twtools_pro );

sub blog_config_template {
	my $app = MT->instance->app;
	my $q = $app->param();
	my $blog_id = $q->param('blog_id');
	my $plugin = MT->component('TwitterTools');
	my $scope = 'system';
	my $config = $plugin->get_config_hash($scope);
	my $blog_config = $plugin->get_config_hash('blog:'.$blog_id);
	my $authed = 1 if ($blog_config->{twitter_access_token} && $blog_config->{twitter_access_secret} && $blog_config->{twitter_username});
	my $oauth_ready = 1 if ($config->{twitter_consumer_key} || MT->config('TwitterToolsOAuthConsumerKey'));
	my $pro = twtools_pro();
    my $tmpl = <<EOT;
	<mt:var name="blog_id" value="$blog_id">
	<mt:var name="authed" value="$authed">
	<mt:var name="oauth_ready" value="$oauth_ready">
	<mt:var name="pro" value="$pro">
	
	<mt:if name="authed">
		<mtapp:statusmsg
            id="authed"
            class="info">
            <p>Twitter user <strong><a href="http://twitter.com/<mt:var name="twitter_username">" target="_blank"><mt:var name="twitter_username"></a></strong> has been authorized for this blog. New entries will be posted to this Twitter account.  To use a different Twitter account or to re-authorize, use the button below.</p>
        </mtapp:statusmsg>
		
		<input type="hidden" name="twitter_username" id="twitter_username" value="<mt:var name="twitter_username" escape="html">" />
		<input type="hidden" name="twitter_access_token" id="twitter_access_token" value="<mt:var name="twitter_access_token" escape="html">" />
		<input type="hidden" name="twitter_access_secret" id="twitter_access_secret" value="<mt:var name="twitter_access_secret" escape="html">" />
	</mt:if>
	
	<mtapp:setting
	    id="twitter_aoauth"
	    label="<__trans phrase="Twitter Authorization">"
	    hint="Sign in with Twitter to authorize Twitter Tools to access your Twitter account."
		class="actions-bar"
	    show_hint="1">
	        <a href="<mt:CGIPath><mt:AdminScript>?__mode=twittertools&amp;blog_id=$blog_id&amp;return_args=__mode%3Dcfg_plugins%26%26blog_id%3D$blog_id"><img src="<mt:StaticWebPath>plugins/TwitterTools/images/signin_with_twitter.png" /></a>
	</mtapp:setting>
	
	<mtapp:setting
	    id="auto_tweet"
	    label="<__trans phrase="Auto-Tweet New Entries">"
	    hint="<__trans phrase="Automatically send a tweet when a new entry is published.  Applies to Twitter accounts authorized for both this blog and for the entry author.">"
	    show_hint="1">
	    <input type="checkbox" name="auto_tweet" id="auto_tweet" value="1" <mt:If name="auto_tweet">checked</mt:If> />
	</mtapp:setting>
	
	<mtapp:setting
	    id="tweet_prefix"
	    label="<__trans phrase="Tweet Prefix">"
	    hint="<__trans phrase="Enter an (optional) prefix for your tweets.  For example: 'New post:' or 'New entry:'.">"
	    show_hint="1">
	    <input name="tweet_prefix" id="tweet_prefix" value="<mt:var name="tweet_prefix" escape="html">" size="40" />
	</mtapp:setting>
	
	<mtapp:setting
	    id="default_hashtags"
	    label="<__trans phrase="Hashtags">"
	    hint="<__trans phrase="Enter one or more hashtags to append to EVERY tweet.  For example: '#mthacks #twitter'.">"
	    show_hint="1">
	    <input name="default_hashtags" id="default_hashtags" value="<mt:var name="default_hashtags" escape="html">" size="40" />
	</mtapp:setting>
	
	<mtapp:setting
	    id="entry_hashtags"
	    label="<__trans phrase="Use Entry Tags as Hashtags">"
	    hint="<__trans phrase="Append the Entry Tags to the Tweet as #hashtags, if there is room left in the 140 character limit.">"
	    show_hint="1">
	    <input type="checkbox" name="entry_hashtags" id="entry_hashtags" value="1" <mt:If name="entry_hashtags">checked</mt:If> />
	</mtapp:setting>

<mt:If name="pro">	
	<mtapp:setting
	    id="tweet_field"
	    label="<__trans phrase="Tweet Field">"
	    hint="<__trans phrase="Choose the Entry field to use for the tweet text.  If you chose 'Custom Field', you need to create an Entry Custom Field called 'Tweet' and use that for your desired Tweet text. Note that if the chosen entry field is blank, no tweet will be sent.">"
	    show_hint="1">
	    <select name="tweet_field">
			<option value="title" <mt:if name="tweet_field" eq="title"> selected="selected"</mt:if>>Title</option>
			<option value="text" <mt:if name="tweet_field" eq="text"> selected="selected"</mt:if>>Body</option>
			<option value="text_more" <mt:if name="tweet_field" eq="text_more"> selected="selected"</mt:if>>Extended</option>
			<option value="excerpt" <mt:if name="tweet_field" eq="excerpt"> selected="selected"</mt:if>>Excerpt</option>
			<option value="keywords" <mt:if name="tweet_field" eq="keywords"> selected="selected"</mt:if>>Keywords</option>
			<option value="custom" <mt:if name="tweet_field" eq="custom"> selected="selected"</mt:if>>Custom Field</option>
		</select>
	</mtapp:setting>
	
	<mtapp:setting
	    id="filter_cats"
	    label="<__trans phrase="Only Tweet with Categories">"
	    hint="<__trans phrase="Enter a comma seperated list of Categories (case-sensitive). **ONLY** entries in any of these Categories will be tweeted. Leave blank to tweet entries from all Categories.">"
	    show_hint="1">
	    <input name="filter_cats" id="filter_cats" value="<mt:var name="filter_cats" escape="html">" size="40" />
	</mtapp:setting>
	
	<mtapp:setting
	    id="filter_tags"
	    label="<__trans phrase="Only Tweet with Tags">"
	    hint="<__trans phrase="Enter a comma seperated list of Tags (case-sensitive). **ONLY** entries with any of these Tags will be tweeted. Leave blank to tweet entries with any tag (or none).">"
	    show_hint="1">
	    <input name="filter_tags" id="filter_tags" value="<mt:var name="filter_tags" escape="html">" size="40" />
	</mtapp:setting>
</mt:If>
	
	<mtapp:setting
	    id="never_shorten"
	    label="<__trans phrase="Never Shorten URLs">"
	    hint="<__trans phrase="(Advanced) If this box is checked the plugin will never shorten entry URLs. Note that the Twitter API may still shorten URLs if tweets or URLs are very long.">"
	    show_hint="1">
	    <input type="checkbox" name="never_shorten" id="never_shorten" value="1" <mt:If name="never_shorten">checked</mt:If> />
	</mtapp:setting>
	
	<mtapp:setting
	    id="shortner_service"
	    label="<__trans phrase="URL Shortner Service">"
	    hint="<__trans phrase="The name of the URL shortner service (optional). Must be exactly one of: Bitly, TinyURL, Awesm, Moopz.">"
	    show_hint="1">
	    <input name="shortner_service" id="shortner_service" value="<mt:var name="shortner_service" escape="html">" size="40" />
	</mtapp:setting>

	<mtapp:setting
	    id="shortner_username"
	    label="<__trans phrase="URL Shortner Username">"
	    hint="<__trans phrase="The username of the URL shortner account (if applicable).">"
	    show_hint="1">
	    <input name="shortner_username" id="shortner_username" value="<mt:var name="shortner_username" escape="html">" size="40" />
	</mtapp:setting>

	<mtapp:setting
	    id="shortner_apikey"
	    label="<__trans phrase="URL Shortner API Key">"
	    hint="<__trans phrase="The API key or password of the URL shortner account (if applicable).">"
	    show_hint="1">
	    <input name="shortner_apikey" id="shortner_apikey" value="<mt:var name="shortner_apikey" escape="html">" size="40" />
	</mtapp:setting>
EOT
}

sub twitter_oauth {
	my $app = shift;
    my $q = $app->param;
	my $return_to = $q->param('return_to') || $app->cookie_val('return_to');
	my $user;
	my $profile;
	my $access_token;
	my $access_secret;
	
	if ($q->param('oauth_token')) {
		($profile, $access_token, $access_secret) = _do_oauth_login($app);
	} else {
		return _start_oauth_login($app,'twittertools');
	}
	my $blog_id = $q->param('blog_id');
	if (!$blog_id && $return_to =~ m/blog_id=([0-9]+)/) {
		$blog_id = $1;
		$app->param('blog_id',$blog_id);
	}

	my $plugin = MT->component('TwitterTools');
	my $scope = 'blog:'.$blog_id;
	my $config = $plugin->get_config_hash($scope);

	$plugin->set_config_value('twitter_access_token', $access_token, $scope);
	$plugin->set_config_value('twitter_access_secret', $access_secret, $scope);
	$plugin->set_config_value('twitter_username', $profile->{screen_name}, $scope);
	
	$app->build_page( $plugin->load_tmpl('oauth_success.tmpl'),
        { return_url => $return_to, twitter_username => $profile->{name}, twitter_screen_name => $profile->{screen_name}} );
}

sub _start_oauth_login {
	my ($app, $mode, $args) = @_;
#MT->log("mode is $mode");
	my $q = $app->param;
	my $client = _get_client($app);
	my $callback = _callback_url($app, $mode, $args);
	my $url = $client->get_authorization_url(callback => $callback);
	my $request_token = $client->request_token;
	my $request_secret = $client->request_token_secret;
	
	my %token_cookie = (
        -name    => 'tw_request_token',
        -value   => $request_token,
        -path    => '/',
        -expires => "+300s"
    );
    $app->bake_cookie(%token_cookie);
	my %secret_cookie = (
        -name    => 'tw_request_secret',
        -value   => $request_secret,
        -path    => '/',
        -expires => "+300s"
    );
    $app->bake_cookie(%secret_cookie);
	my $return_to = $app->return_uri;
	my %return_cookie = (
        -name    => 'return_to',
        -value   => $return_to,
        -path    => '/',
        -expires => "+300s"
    );
    $app->bake_cookie(%return_cookie);
	$app->redirect($url);
}

sub _do_oauth_login {
	my ($app) = @_;
	my $q = $app->param;
	my $request_token = $q->param('oauth_token');
	return 'request tokens dont match'  if ($request_token ne $app->cookie_val('tw_request_token'));   # todo: better error handling
	
	my $request_secret = $app->cookie_val('tw_request_token');

	my $client = _get_client($app);
	$client->request_token($request_token);
	$client->request_token_secret($request_secret);
	my($access_token, $access_secret) = $client->request_access_token(verifier => $q->param('oauth_verifier'));

	my $profile = eval{ $client->verify_credentials() };
	if ( my $error = $@ ) {
		MT->log("Twitter Tools error during OAuth validation: $error");
	    if ( blessed $error && $error->isa("Net::Twitter::Lite::Error")
	         && $error->code() == 401 ) {
	    	return 0;
	    }
	    MT->log("Twitter Tools error during OAuth validation: $error");
	}
	return ($profile, $access_token, $access_secret) if $profile;
}

sub _callback_url {
	my ($app, $mode, $args) = @_;
	my $cgi_path = $app->config('CGIPath');
    $cgi_path .= '/' unless $cgi_path =~ m!/$!;
    my $url 
        = $cgi_path 
        . $app->config('AdminScript')
        . $app->uri_params(
        'mode' => $mode,
        args => $args
        );

    if ( $url =~ m!^/! ) {
		my $host = $ENV{SERVER_NAME} || $ENV{HTTP_HOST};
        $host =~ s/:\d+//;
        my $port = $ENV{SERVER_PORT};
        my $cgipath = '';
        $cgipath = $port == 443 ? 'https' : 'http';
        $cgipath .= '://' . $host;
        $cgipath .= ( $port == 443 || $port == 80 ) ? '' : ':' . $port;
        $url = $cgipath . $url;
    }
	return $url;
}

sub _get_client {
	my ($app) = @_;
	my $q = $app->param;
	my $plugin = MT->component('TwitterTools');
	my $config = $plugin->get_config_hash('system');
	my $consumer_key = $config->{twitter_consumer_key} || MT->config('TwitterToolsOAuthConsumerKey');
	my $consumer_secret = $config->{twitter_consumer_secret} || MT->config('TwitterToolsOAuthConsumerSecret');
	use Net::Twitter::Lite::WithAPIv1_1;
	my $client = Net::Twitter::Lite::WithAPIv1_1->new(
		consumer_key    => $consumer_key,
		consumer_secret => $consumer_secret,
		ssl             => 1,
	);
	return $client;
}

1;