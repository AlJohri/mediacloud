
var fs = require('fs');
//var page = require('webpage').create();

function capture_and_render( url, base_name )
{

}

function capture_func( q0, q1 )
{
    console.log('capturing');

    console.log(q0);

    //q0 = 94946;

    var url = 'http://www.mediacloud.org/dashboard/view/1?q1=' + q0;
    console.log( url );

    var page = require('webpage').create();

    var output_dir = 'screen_shots';

    page.open(url, function() {
	console.log('rendering non wconly' + url);
	page.render(output_dir + '/mc_' + q0 + '.png');
	page.render(output_dir + '/mc_' + q0 + '.pdf');
	console.log('captured');
	//phantom.exit();
    });

    var url_2 = url + '&wconly=1';

    var page_2 =  require('webpage').create();

    page_2.open(url_2, function(status) {
	console.log('rendering' + url_2);
	console.log( status );
	page_2.render(output_dir + '/mc_' + q0 + '_wc_only' + '.png');
	page_2.render(output_dir + '/mc_' + q0 + '_wc_only' + '.pdf');
	console.log('captured');
	//phantom.exit();
    });

}

var stream =  fs.open('/tmp/json', 'r');
var json_str = stream.readLine();

data = JSON.parse(json_str);

//stream.close();

data.forEach( function( pop_query ) {
    var q0 = pop_query[  "queries_id_0" ];
    var q1 = pop_query[  "queries_id_2" ];
    capture_func( q0, q1 );
});

//phantom.exit();