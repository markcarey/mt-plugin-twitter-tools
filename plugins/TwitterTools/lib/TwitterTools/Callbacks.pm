package TwitterTools::Callbacks;
use strict;

use MT::Util qw ( trim remove_html );
use TwitterTools::Util qw( shorten truncate_string twtools_pro );

sub entry_pre_save {
	my ($cb, $entry, $entry_orig) = @_;
	return if $entry->twitter_status_id;   # alreaded tweeted
	my $plugin = MT->component('TwitterTools');
	my $config = $plugin->get_config_hash('blog:'.$entry->blog_id);
	my $enabled = $config->{auto_tweet};
	return if !$enabled;
    # MT->log("after return");
	my $entry_id = $entry->id;
	my $tweet_it = 0;
	
	if ($entry->status == 2) {
        # MT->log("after status check");
		if (!$entry_id) {
            # MT->log("no entry_id");
			$tweet_it = 1;   # new entry with published status
		} else {
            # MT->log("entry_id found");
			# entry was previously saved in db -- now determine if it status has just been changed to published
			$entry->clear_cache();
			$entry->uncache_object();
			$entry_orig = MT->model('entry')->load($entry_id);
			if ($entry_orig->status != 2) {
				# now we know status has just been changed to published and we have no status_id on record - so tweet it
				$tweet_it = 1;
			}
		}
	}
	
	if ($tweet_it) {
		# MT->log($entry->title . " just published and should be tweeted");
		$entry->{tweet_it} = 'yes';
	}

}

sub build_page {
    my ($cb, %params) = @_;
    my $entry = $params{Entry};
    return if !$entry;
    # MT->log("build_page for: " . $entry->title);
    my $html = $params{Content};
    my $file = $params{File};
    if ($file && $html) {
        my $fmgr = $entry->blog->file_mgr;
        unless ($fmgr->content_is_updated( $file, $html )) {
            my $key = 'tweetme_' . $entry->id;
            my $session = MT->model('session')->load({ kind => 'TT', id => $key });
            return if !$session;
            # okay should be tweeted
            $session->remove; # prevent duplicate tweets when multiple rpt daemons running
    
            $entry->{tweet_it} = 'manual';
    
            my $ctx = $params{Context};
            my $img_path = $ctx->var('lead_image_path') if $ctx;
            my $skip_it = $ctx->var('no_tweet') if $ctx;

            unless ($skip_it) {
                _tweet_entry($entry, $img_path);
            }
        }
    }
}

sub build_file {
    my ($cb, %params) = @_;
    my $entry = $params{Entry};
    return if !$entry;
    # MT->log("build_file for: " . $entry->title);
    my $key = 'tweetme_' . $entry->id;
    my $session = MT->model('session')->load({ kind => 'TT', id => $key });
    return if !$session;
    # okay should be tweeted
    $session->remove; # prevent duplicate tweets when multiple rpt daemons running
    
    $entry->{tweet_it} = 'yes';
    
    my $ctx = $params{Context};
    my $img_path = $ctx->var('lead_image_path') if $ctx;
    my $skip_it = $ctx->var('no_tweet') if $ctx;

    unless ($skip_it) {
        _tweet_entry($entry, $img_path);
    }
}

sub entry_post_save {
    my ($cb, $entry, $entry_orig) = @_;
    _tweetme($entry->id) if $entry->{tweet_it};
}

sub _tweet_entry {
    my ($entry, $img_path) = @_;
	return if $entry->twitter_status_id;   # alreaded tweeted
	return unless $entry->{tweet_it};
	my $entry_id = $entry->id;
	my $plugin = MT->component('TwitterTools');
	my $config = $plugin->get_config_hash('blog:'.$entry->blog_id);
	my $enabled = $config->{auto_tweet};
	my $pro = twtools_pro();
    # MT->log("Eval error: " . $@) if $@;
    # use Data::Dumper;
    # MT->log("pro is " . Dumper($pro));
	if ( $enabled && $pro && ($entry->{tweet_it} eq 'yes') ) {
		MT->log("inside pro filters if");
		$enabled = TwitterTools::Pro::Callbacks::auto_tweet_filters($entry, $config);
		MT->log("after filter check enabled is now $enabled");
	}
	return if !$enabled;
	my $access_token = $config->{twitter_access_token};
	my $access_secret = $config->{twitter_access_secret};
	my $twitter_username = $config->{twitter_username};

	# MT->log("entry tweet_it is:" . $entry->{tweet_it});

	## Send Twitter posts in the background.
#    MT::Util::start_background_task(
#        sub {
			my $client;
			if ( $entry->authored_on =~
                m!(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})(?::(\d{2}))?! ) {
				my $s = $6 || 0;
				my $ts = sprintf "%04d%02d%02d%02d%02d%02d", $1, $2, $3, $4, $5, $s;
				$entry->authored_on($ts);
			}
			my $user = $entry->author;			

			my $blog_tweet = 1 if ($access_token && $access_secret);
			my $user_tweet = 1 if ($user->twitter_access_token && $user->twitter_access_secret);
			return unless ($blog_tweet || $user_tweet);

			my $prefix = $config->{tweet_prefix} || '';
			$prefix .= ' ' if ($prefix !~ /\s$/);
			my $field = $config->{tweet_field} || 'title';
			my $tweet_text;
			if ($field eq 'custom') {
				if ($entry->has_meta('field.tweet')) {
	                $tweet_text = $entry->meta('field.tweet');
					$tweet_text = MT->app->param("customfield_tweet") if (!$tweet_text);
	            } 
			} else {
				$tweet_text = remove_html($entry->$field);
			}
			return if !$tweet_text;
			my $default_hashtags = $config->{default_hashtags} || '';
			$default_hashtags = ' ' . $default_hashtags unless ($default_hashtags =~ /^\s/);
			
			my $pic_length = 0;
			my $file;
			if ($img_path) {
			    $file = $img_path;
			} else {
			    my $asset = _get_entry_asset($entry);
			    $file = $asset->file_path if $asset;
			}
			$pic_length = 28 if $file;

			my $tweet = $prefix . truncate_string($tweet_text,116 - length($prefix) - length($default_hashtags) - $pic_length); 
			my $chars_left = 115 - length($tweet) - length($default_hashtags);
			my $entry_hashtags = '';
			if ($config->{entry_hashtags}) {
				if (my @tags = $entry->get_tags) {
					foreach my $tag (@tags) {
						$tag =~ s/\s//;  # remove spaces
						$entry_hashtags .= '#' . $tag . ' ' unless ($tag =~ /^\@/);
					}
					$entry_hashtags = truncate_hashtags($entry_hashtags, $chars_left - 1);
					$entry_hashtags = ' ' . $entry_hashtags if $entry_hashtags;
				}
			}
			my $short_url = shorten(MT::Util::strip_index($entry->permalink,$entry->blog), $config);
			if (!$short_url) {
			    $short_url = $entry->permalink;
			}
			$tweet .= ' ' . $short_url . $default_hashtags . $entry_hashtags;
			
			# start blog-level tweet			
			if ($access_token && $access_secret) {
				$client = _get_client();
				$client->access_token($access_token);
				$client->access_token_secret($access_secret);
				my $res;
				if ($file) {
				    $res = $client->update_with_media({ status => $tweet, media => [ $file ] });
				} else {
				    $res = $client->update({ status => $tweet });
				}
				if ($res->{id}) {
					$entry->twitter_status_id($res->{id});
					$entry->twitter_short_url($short_url) if ($short_url ne $entry->permalink);
					$entry->save;
				}
				$entry->{tweeted}{$twitter_username} = 1;
			}
			
			# start user-level tweet
			if ($user->twitter_access_token && $user->twitter_access_secret && !$entry->{tweeted}{$user->twitter_username}) {
				$client ||= _get_client();
				$client->access_token($user->twitter_access_token);
				$client->access_token_secret($user->twitter_access_secret);
				my $res;
				if ($file) {
				    $res = $client->update_with_media({ status => $tweet, media => [ $file ] });
				} else {
				    $res = $client->update({ status => $tweet });
				}
				if ($res->{id} && !$entry->twitter_status_id) {
					$entry->twitter_status_id($res->{id});
					$entry->twitter_short_url($short_url) if ($short_url ne $entry->permalink);
					$entry->save;
				}
			}
			
#        }
#    );

	return 1;
}

sub _get_entry_asset {
    my ($e) = @_;
    my @assets;
    my $asset;
    if ($e->has_summary('all_assets')) {
        @assets = $e->get_summary_objs('all_assets' => 'MT::Asset');
    }
    else {
        require MT::ObjectAsset;
        @assets = MT->model("asset")->load({ class => 'image' }, { join => MT::ObjectAsset->join_on(undef, {
            asset_id => \'= asset_id', object_ds => 'entry', object_id => $e->id })});
    }
    $asset = $assets[0] if @assets;
    return $asset;
}

sub _tweetme {
    my ($entry_id) = @_;
    my $key = 'tweetme_' . $entry_id;
    my $session = MT->model('session')->load({ kind => 'TT', id => $key });
    next if ($session); #if the session exists that means we queued this already
    
    # now create session
    $session = MT->model('session')->new;
    $session->kind('TT');
    $session->id($key);
    $session->start(time);
    $session->save;
}

sub truncate_hashtags {
    my($text, $max) = @_;
	my $len = length($text);
	return $text if $len <= $max;
    my @words = split /\s+/, $text;
	$text = '';
	foreach my $word (@words) {
		if (length($text . $word) <= $max) {
			$text .= $word . ' ';
		}
	}
	$text = trim($text);
    return $text;
}

sub _get_client {
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