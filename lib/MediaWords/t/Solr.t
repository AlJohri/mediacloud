#!/usr/bin/env perl

use strict;
use warnings;

# test MediaWords::Solr::_get_stories_ids_from_stories_only_params, which
# does simple parsing of solr queries to find out if there is only a list of
# stories_ids, in which case it just returns the story ids directly

BEGIN
{
    use FindBin;
    use lib "$FindBin::Bin/../lib";
    use lib $FindBin::Bin;
}

use MediaWords::CommonLibs;

use English '-no_match_vars';

use Data::Dumper;
use Encode;
use Test::More;
use Test::Deep;

BEGIN
{
    use_ok( 'MediaWords::Solr' );
}

use MediaWords::Test::API;
use MediaWords::Test::DB;
use MediaWords::Test::Solr;
use MediaWords::Test::Supervisor;

# run the given set of params against _gsifsop and verify that the given list of stories_ids (or undef) is returned
sub test_stories_id_query
{
    my ( $params, $expected_stories_ids, $label ) = @_;

    my $got_stories_ids = MediaWords::Solr::_get_stories_ids_from_stories_only_params( $params );

    if ( $expected_stories_ids )
    {
        ok( $got_stories_ids, "$label stories_ids defined" );
        return unless ( $got_stories_ids );

        is( scalar( @{ $got_stories_ids } ), scalar( @{ $expected_stories_ids } ), "$label expected story count" );

        my $got_story_lookup = {};
        map { $got_story_lookup->{ $_ } = 1 } @{ $got_stories_ids };

        map { ok( $got_story_lookup->{ $_ }, "$label: expected stories_id $_" ) } @{ $expected_stories_ids };
    }
    else
    {
        is( $got_stories_ids, undef, "$label: expected undef" );
    }
}

sub test_solr_stories_only_query()
{
    test_stories_id_query( { q  => '' }, undef, 'empty q' );
    test_stories_id_query( { fq => '' }, undef, 'empty fq' );
    test_stories_id_query( { q => '', fq => '' }, undef, 'empty q and fq' );
    test_stories_id_query( { q => '', fq => '' }, undef, 'empty q and fq' );

    test_stories_id_query( { q => 'stories_id:1' }, [ 1 ], 'simple q match' );
    test_stories_id_query( { q => 'media_id:1' }, undef, 'simple q miss' );
    test_stories_id_query( { q => '*:*', fq => 'stories_id:1' }, [ 1 ], 'simple fq match' );
    test_stories_id_query( { q => '*:*', fq => 'media_id:1' }, undef, 'simple fq miss' );

    test_stories_id_query( { q => 'media_id:1',   fq => 'stories_id:1' }, undef, 'q hit / fq miss' );
    test_stories_id_query( { q => 'stories_id:1', fq => 'media_id:1' },   undef, 'q miss / fq hit' );

    test_stories_id_query( { q => '*:*', fq => [ 'stories_id:1', 'stories_id:1' ] }, [ 1 ], 'fq list hit' );
    test_stories_id_query( { q => '*:*', fq => [ 'stories_id:1', 'media_id:1' ] }, undef, 'fq list miss' );

    test_stories_id_query( { q => 'stories_id:1', fq => '' },             [ 1 ], 'q hit / empty fq' );
    test_stories_id_query( { q => 'stories_id:1', fq => [] },             [ 1 ], 'q hit / empty fq list' );
    test_stories_id_query( { q => '*:*',          fq => 'stories_id:1' }, [ 1 ], '*:* q / fq hit' );
    test_stories_id_query( { fq => 'stories_id:1' }, undef, 'empty q, fq hit' );
    test_stories_id_query( { q  => '*:*' },          undef, '*:* q' );

    test_stories_id_query( { q => 'stories_id:( 1 2 3 )' }, [ 1, 2, 3 ], 'q list' );
    test_stories_id_query(
        { q => 'stories_id:( 1 2 3 )', fq => 'stories_id:( 1 3 4 )' },
        [ 1, 3 ],
        'q list / fq list intersection'
    );
    test_stories_id_query( { q => '( stories_id:2 )' }, [ 2 ], 'q parens' );
    test_stories_id_query( { q => '(stories_id:3)' },   [ 3 ], 'q parens no spaces' );

    test_stories_id_query( { q => 'stories_id:4 and stories_id:4' }, [ 4 ], 'q simple and' );
    test_stories_id_query( { q => 'stories_id:( 1 2 3 ) and stories_id:( 2 3 4 )' }, [ 2, 3 ], 'q and intersection' );
    test_stories_id_query( { q => 'stories_id:( 1 2 3 ) and stories_id:( 4 5 6 )' }, [], 'q and empty intersection' );

    test_stories_id_query(
        { q => 'stories_id:( 1 2 3 4 ) and ( stories_id:( 2 3 4 5 6 ) and stories_id:( 3 4 ) )' },
        [ 3, 4 ],
        'q complex and intersection'
    );
    test_stories_id_query( { q => 'stories_id:( 1 2 3 4 ) and ( stories_id:( 2 3 4 5 6 ) and media_id:1 )' },
        undef, 'q complex and intersection miss' );
    test_stories_id_query( { q => 'stories_id:( 1 2 3 4 ) and ( stories_id:( 2 3 4 5 6 ) and stories_id:( 243 ) )' },
        [], 'q complex and intersection empty' );
    test_stories_id_query(
        { q => 'stories_id:( 1 2 3 4 ) and stories_id:( 2 3 4 5 6 ) and stories_id:( 3 4 )' },
        [ 3, 4 ],
        'q complex and intersection'
    );

    test_stories_id_query( { q => 'stories_id:1 and ( stories_id:2 and ( stories_id:3 and obama ) )' },
        undef, 'q complex boolean query with buried miss' );
    test_stories_id_query( { q => '( ( stories_id:1 or stories_id:2 ) and stories_id:3 )' },
        undef, 'q complex boolean query with buried or' );

    test_stories_id_query( { q => 'stories_id:( 1 2 3 4 5 6 )', foo => 'bar' }, undef, 'unrecognized parameters' );
    test_stories_id_query( { q => 'stories_id:( 1 2 3 4 5 6 )', start => '2' }, [ 3, 4, 5, 6 ], 'start parameter' );
    test_stories_id_query(
        { q => 'stories_id:( 1 2 3 4 5 6 )', start => '2', rows => 2 },
        [ 3, 4 ],
        'start and rows parameter'
    );
    test_stories_id_query( { q => 'stories_id:( 1 2 3 4 5 6 )', rows => 2 }, [ 1, 2 ], 'rows parameter' );
}

# generate a utf8 string and append it to the title of the given stories, both in the hashes and in
# the database, and also add a sentence including the utf8 string to the db.  return the add utf8 string.
sub append_utf8_string_to_stories($$)
{
    my ( $db, $stories ) = @_;

    my $utf8_string = "ind\x{ed}gena";

    # my $utf8_string = "foobarbaz";

    for my $story ( @{ $stories } )
    {
        $story->{ title } = "$story->{ title } $utf8_string";
        $db->update_by_id( 'stories', $story->{ stories_id }, { title => $story->{ title } } );

        $db->query( <<SQL, encode_utf8( $utf8_string ), $story->{ stories_id } );
insert into story_sentences
    ( stories_id, sentence_number, sentence, media_id, publish_date, db_row_last_updated, language, is_dup )
    select
            stories_id, 0, ?, media_id, publish_date, db_row_last_updated, language, false
        from stories
        where stories_id = ?
SQL
    }

    return $utf8_string;
}

sub test_query($$$$)
{
    my ( $db, $solr_query, $expected_ss, $label ) = @_;

    my $r = eval { MediaWords::Solr::query( $db, { q => $solr_query, rows => 1_000_000 } ) };
    ok( !$@, "$label query error: $@" );

    my $fields = [ qw/stories_id/ ];
    rows_match( "$label sentences", $r->{ response }->{ docs }, $expected_ss, 'story_sentences_id', $fields );
}

sub test_queries($)
{
    my ( $db ) = @_;

    my $label = "test_queries";

    my $test_data = MediaWords::Test::DB::create_test_story_stack_numerated( $db, 5, 1, 10 );
    MediaWords::Test::DB::add_content_to_test_story_stack( $db, $test_data );

    my $stories      = [ grep { $_->{ stories_id } } values( %{ $test_data } ) ];
    my $utf8_stories = [ grep { !( $_->{ stories_id } % 3 ) } @{ $stories } ];
    my $utf8_string = append_utf8_string_to_stories( $db, $utf8_stories );

    MediaWords::Test::Solr::setup_test_index( $db );

    my $first_story = $stories->[ 0 ];

    {
        my $expected = $db->query( <<SQL, $first_story->{ stories_id } )->hashes;
select * from story_sentences where stories_id = ?
SQL
        test_query( $db, "stories_id:$first_story->{ stories_id } and sentence:*", $expected, "$label stories_id" );
    }
    {
        my $media_id = $first_story->{ media_id };
        my $expected = $db->query( <<SQL, $media_id )->hashes;
select * from story_sentences where media_id = ?
SQL
        test_query( $db, "media_id:$media_id and sentence:*", $expected, "$label media_id" );
    }
    {
        my $expected = $db->query( <<SQL, encode_utf8( $utf8_string ) )->hashes;
select ss.* from story_sentences ss where sentence ilike '%' || ? || '%'
SQL
        test_query( $db, $utf8_string, $expected, "$label utf8_string" );
    }

}

sub main
{
    test_solr_stories_only_query();

    MediaWords::Test::Supervisor::test_with_supervisor( \&test_queries, [ qw/solr_standalone/ ] );

    done_testing();
}

main();
