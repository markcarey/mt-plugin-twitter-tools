package TwitterTools::Pro::Worker::Import;

use strict;
use base qw( TheSchwartz::Worker );

use MT::Util qw( epoch2ts );
use HTTP::Date qw( str2time );

use TheSchwartz::Job;

sub work {
    my $class                = shift;
    my TheSchwartz::Job $job = shift;
 	my $results              = $job->arg;
use Data::Dumper;
    import_tweets($results);
    eval {
MT->log('inside eval block');
    };
	if ( $@ ) {
        $job->failed( qq{TwitterTools::Pro::Worker::Import could not import tweets } .
                $job->uniqkey . ': ' . $@ );
    } else {
        $job->completed();
    }
}

sub grab_for    {120}
sub max_retries {3}
sub retry_delay {120}


sub import_tweets {
#MT->log('start import_tweets');
	my ($results) = @_;
#MT->log("results->{blog_id} is: " . $results->{blog_id});
	my $blog_id = $results->{blog_id};
	my $blog = MT->model('blog')->load($blog_id);
	my @tweets = @{$results->{results}};
    TWEET: foreach my $status (@tweets) {
#MT->log('working on tweet ' . Dumper($status));
		my $epoch = str2time($status->{created_at});
#MT->log("import tweet epoch is $epoch");
		my $ts = epoch2ts($blog,$epoch);
#MT->log("import tweet ts is $ts");
		my $username = $status->{from_user};
		# does user exist in database?
		my $user = MT->model('author')->load({ name => $username, auth_type => 'Twitter' });
#MT->log("after user lookup");
		if (!$user) {
#MT->log("before asset creation");
			my $asset = _asset_from_url($status->{profile_image_url});
#MT->log("after asset creation");
			# user not in DB, so add them
			$user = MT->model('author')->new;
			$user->name($username);
			$user->nickname($username);
			$user->auth_type('Twitter');
			$user->url('http://twitter.com/' . $username);
			$user->password('(none)');
			$user->type(2);
			$user->userpic_asset_id($asset->id) if $asset;
			$user->save
				or MT->log('Error creating user for tweet: ' . $user->errstr);
			if ($asset) {
				$asset->created_by($user->id);
				$asset->save;
			}
		}
#MT->log("b4 new tweet blog_id: $blog_id ts: $ts user id: " . $user->id);
		my $tweet = MT->model('entry')->get_by_key({ blog_id => $blog_id, author_id => $user->id, authored_on => $ts });
#MT->log("tweet id is: " . $tweet->id) if $tweet->id;
		next TWEET if $tweet->id;
#		$tweet = MT->model('entry')->new;
#MT->log("after new tweet");
#		$tweet->author_id($user->id);
#		$tweet->blog_id($blog->id);
		$tweet->title($status->{text});
		$tweet->twitter_status_id($status->{id});
		$tweet->status(2);
		$tweet->allow_comments(1);
		$tweet->allow_pings(0);
#		$tweet->authored_on($ts);
		# todo auto-tagger
		my @hashtags = extract_hashtags($status->{text});
#MT->log("extracted hashtags are:" . Dumper(\@hashtags));
		$tweet->add_tags(@hashtags) if @hashtags;
		my $keyword_list;
		my $first = 1;
		foreach my $keyword (@hashtags) {
			$keyword_list .= ',' unless $first;
			$keyword_list .= $keyword;
			$first = 0;
		}
		$tweet->keywords($keyword_list);
		$tweet->save
			or MT->log('Error importing tweet: ' . $tweet->errstr);
		MT->app->rebuild_entry(Entry => $tweet);
	}
	MT->app->rebuild_indexes(BlogID => $blog_id );
	return 1;
}

sub extract_hashtags {
	my ($text) = @_;
	my @tag_names;
	while ($text =~ m/(\A|\s)\#(\w+)/g) {
		my $hashtag = lc($2);
		next unless ($hashtag =~ m/[a-z]/);
		push @tag_names, $hashtag;
	}
	return @tag_names;
}

sub _get_ua {
    return MT->new_ua( { paranoid => 1 } );
}

sub _asset_from_url {
    my ($image_url) = @_;
    my $ua   = _get_ua() or return;
    my $resp = $ua->get($image_url);
    return undef unless $resp->is_success;
    my $image = $resp->content;
    return undef unless $image;
    my $mimetype = $resp->header('Content-Type');
    my $def_ext = {
        'image/jpeg' => '.jpg',
        'image/png'  => '.png',
        'image/gif'  => '.gif'}->{$mimetype};

    require Image::Size;
    my ( $w, $h, $id ) = Image::Size::imgsize(\$image);

    require MT::FileMgr;
    my $fmgr = MT::FileMgr->new('Local');

    my $save_path  = '%s/support/uploads/';
    my $local_path =
      File::Spec->catdir( MT->instance->static_file_path, 'support', 'uploads' );
    $local_path =~ s|/$||
      unless $local_path eq '/';    ## OS X doesn't like / at the end in mkdir().
    unless ( $fmgr->exists($local_path) ) {
        $fmgr->mkpath($local_path);
    }
    my $filename = substr($image_url, rindex($image_url, '/'));
    if ( $filename =~ m!\.\.|\0|\|! ) {
        return undef;
    }
    my ($base, $uploaded_path, $ext) = File::Basename::fileparse($filename, '\.[^\.]*');
    $ext = $def_ext if $def_ext;  # trust content type higher than extension

    # Find unique name for the file.
    my $i = 1;
    my $base_copy = $base;
    while ($fmgr->exists(File::Spec->catfile($local_path, $base . $ext))) {
        $base = $base_copy . '_' . $i++;
    }

    my $local_relative = File::Spec->catfile($save_path, $base . $ext);
    my $local = File::Spec->catfile($local_path, $base . $ext);
    $fmgr->put_data( $image, $local, 'upload' );

    require MT::Asset;
    my $asset_pkg = MT::Asset->handler_for_file($local);
    return undef if $asset_pkg ne 'MT::Asset::Image';

    my $asset;
    $asset = $asset_pkg->new();
    $asset->file_path($local_relative);
    $asset->file_name($base.$ext);
    my $ext_copy = $ext;
    $ext_copy =~ s/\.//;
    $asset->file_ext($ext_copy);
    $asset->blog_id(0);

    my $original = $asset->clone;
    my $url = $local_relative;
    $url  =~ s!\\!/!g;
    $asset->url($url);
    $asset->image_width($w);
    $asset->image_height($h);
    $asset->mime_type($mimetype);

    $asset->save
        or return undef;

    MT->run_callbacks(
        'api_upload_file.' . $asset->class,
        File => $local, file => $local,
        Url => $url, url => $url,
        Size => length($image), size => length($image),
        Asset => $asset, asset => $asset,
        Type => $asset->class, type => $asset->class,
    );
    MT->run_callbacks(
        'api_upload_image',
        File => $local, file => $local,
        Url => $url, url => $url,
        Size => length($image), size => length($image),
        Asset => $asset, asset => $asset,
        Height => $h, height => $h,
        Width => $w, width => $w,
        Type => 'image', type => 'image',
        ImageType => $id, image_type => $id,
    );

    $asset;
}

1;