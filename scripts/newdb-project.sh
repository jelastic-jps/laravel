#!/bin/bash
proj=$1 #Project name, use upper case for the first letter
dbhost=$2 #Database hostname. In case of database cluster use layer name sqld to ensure HA DNS RR failover. More details at: https://docs.jelastic.com/container-dns-hostnames#layer-hostnames
usr=$3 #Database entry point username
pswd=$4 #Database entry point password

if [[ $# -lt 4 ]] ; then
echo;echo Not enough arguments supplied!;echo;echo Usage: $0 Project_name db_host db_username db_password;echo;echo Use upper case for the first letter in Project_name;echo;echo Example: ./newdb-project.sh Myproject sqldb.mysqldb.jelastic.com jelastic-user jelastic-passwd;echo;exit
exit 1
fi

WEBROOT=/var/www/webroot
mypath=$WEBROOT/ROOT/$proj
envfile=$mypath/.env
database=$mypath/config/database.php
cd $WEBROOT/ROOT
laravel new $proj #Creates new Laravel Project
cd $mypath

export lowercase=`echo $proj | awk '{print tolower($0)}'` #Changes Project name to lowercase

mysql -u$usr -p$pswd -h$dbhost -e "CREATE DATABASE IF NOT EXISTS $lowercase;"

#Changes database credentials in file: .env
#sed -i "s|mysql|pgsql|g" $envfile #Uncomment this line in case of PostgreSQL database or change regexp to use other database type. By default Laravel uses MySQL database
sed -i "s|^DB_HOST=*.*|DB_HOST=$dbhost|g" $envfile
sed -i "s|^DB_DATABASE=*.*|DB_DATABASE=$lowercase|g" $envfile
sed -i "s|^DB_USERNAME=*.*|DB_USERNAME=$usr|g" $envfile
sed -i "s|^DB_PASSWORD=*.*|DB_PASSWORD=$pswd|g" $envfile

#Changes database credentials in file: config/databse.php
sed -i "s|'DB_HOST', '127.0.0.1'|'DB_HOST', '$dbhost'|g" $database
sed -i "s|'DB_DATABASE', 'forge'|'DB_DATABASE', '$lowercase'|g" $database
sed -i "s|'DB_USERNAME', 'forge'|'DB_USERNAME', '$usr'|g" $database
sed -i "s|'DB_PASSWORD', ''|'DB_PASSWORD', '$pswd'|g" $database

#php artisan make:auth #Rolls out authentications system
composer require laravel/ui
php artisan ui vue --auth
php artisan make:migration create_$lowercase\_table --create=$lowercase #Prepares migration

lastletter='s' #To create a table name the project name should be changed to plural adding s letter
tablename=$lowercase$lastletter

sed -i "s|$lowercase|$tablename|g" $mypath/database/migrations/*$lowercase_table.php

#Adds more fields to table structure such as title, url and description
sed -i "s|\$table->bigIncrements('id');|\$table->bigIncrements('id');\n\$table->string('title');\n\$table->string('url');\n\$table->text('description');|g" $mypath/database/migrations/*$lowercase_table.php

#Generates model factory files that allow to generate fake data that we'll use to fill our database
php artisan make:model --factory $proj

sed -i "s|\/\/|'title' => substr(\$faker->sentence(2), 0, -1),\n'url' => \$faker->url,\n'description' => \$faker->paragraph,|g" $mypath/database/factories/$proj\Factory.php

#Fills out the table with fake data######
php artisan make:seeder $proj\TableSeeder


sed -i "s|\/\/|factory(App\\\\$proj::class, 5)->create();|g" $mypath/database/seeds/$proj\TableSeeder.php

sed -i "s|\/\/ \$this->call(UsersTableSeeder::class);|\$this->call($proj\TableSeeder::class);|g" $mypath/database/seeds/DatabaseSeeder.php

php artisan migrate:refresh --seed
#########################################
#Reads fake data from the table for testing to make sure the data were inserted into the table
mysql -u$usr -p$pswd -h$dbhost -e "select * from $lowercase.$tablename\G;"


#Next code block is related to displaying the fake generated data stored in the table and updates the table with data we want(Jelastic related links)
#Replaces content of routes/web.php#########
rm -f $mypath/routes/web.php
#Updates a root route by getting a collection of urls from the table and passing them to be displayed
cat << EOF >> $mypath/routes/web.php
<?php
Route::get('/', function () {
    \$links = \App\\$proj::all();

    return view('welcome', ['links' => \$links]);
});

EOF
###########################################
#Updates welcome page to show all the urls read from the table
sed -n '/<a href="https/!p' $mypath/resources/views/welcome.blade.php > $mypath/resources/views/welcome.blade1.php
sed -i "s|<div class=\"links\">|<div class=\"links\">\n@foreach (\$links as \$link)\n<a href=\"{{ \$link->url }}\">{{ \$link->title }}</a>\n@endforeach|g" $mypath/resources/views/welcome.blade1.php
mv $mypath/resources/views/welcome.blade1.php $mypath/resources/views/welcome.blade.php

#Submit and Insert routes are added
cat << EOF >> $mypath/routes/web.php

Route::get('/submit', function () {
    return view('insertForm');
});

Route::post('/insert', 'Controller@insert');
 
EOF

#Creates an Insert Form template in the simple HTML style with Jelastic related predefined useful links
cat << EOF >> $mypath/resources/views/insertForm.blade.php
<!doctype html>
<html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">

        <title>Laravel links update</title>

        <!-- Fonts -->
        <link href="https://fonts.googleapis.com/css?family=Nunito:200,600" rel="stylesheet">

        <!-- Styles -->
        <style>
            html, body {
                background-color: #fff;
                color: #636b6f;
                font-family: 'Nunito', sans-serif;
                font-weight: 200;
                height: 100vh;
                margin: 0;
            }

            .full-height {
                height: 100vh;
            }

            .flex-center {
                align-items: center;
                display: flex;
                justify-content: center;
            }

            .position-ref {
                position: relative;
            }

            .top-right {
                position: absolute;
                right: 10px;
                top: 18px;
            }

            .content {
                text-align: center;
            }

            .title {
                font-size: 84px;
            }

            .links > a {
                color: #636b6f;
                padding: 0 25px;
                font-size: 13px;
                font-weight: 600;
                letter-spacing: .1rem;
                text-decoration: none;
                text-transform: uppercase;
            }

            .m-b-md {
                margin-bottom: 30px;
            }
        </style>
    </head>
    <body>
	<center>
<font size="10">Edit links and press Replace</font>
	    <form action="../public/insert" method="post">
	<table border="2">
	<tr>
	<td>
	<table>
		<tr>
		{{ csrf_field() }}
		<td>Title1: </td>
		<td><input type="text" name="title1" value="Jelastic PaaS"></td>
		</tr>
                <tr>    
                <td>Url1: </td>
                <td><input type="text" name="url1" value="https://jelastic.com"></td> 
                </tr>   
                <tr>    
                <td>Description1: </td>
                <td><input type="text" name="description1" value="Jelastic web-site"></td> 
                </tr>   
        </table>
	</td>
	<td>
	<table>
		<tr>
		<td>Title2: </td>
		<td><input type="text" name="title2" value="Jelastic Docs"></td>
		</tr>
                <tr>    
                <td>Url2: </td>
                <td><input type="text" name="url2" value="https://docs.jelastic.com"></td> 
                </tr>   
                <tr>    
                <td>Description2: </td>
                <td><input type="text" name="description2" value="Jelastic Docs"></td> 
                </tr>   
        </table>
        </td>
	<td>
	<table>
		<tr>
		<td>Title3: </td>
		<td><input type="text" name="title3" value="Jelastic Blog"></td>
		</tr>
                <tr>    
                <td>Url3: </td>
                <td><input type="text" name="url3" value="https://jelastic.com/blog"></td> 
                </tr>   
                <tr>    
                <td>Description3: </td>
                <td><input type="text" name="description3" value="Jelastic Blog"></td> 
                </tr>   
        </table>
        </td>
	<td>
	<table>
		<tr>
		{{ csrf_field() }}
		<td>Title4: </td>
		<td><input type="text" name="title4" value="Cloud Scripting"></td>
		</tr>
                <tr>    
                <td>Url4: </td>
                <td><input type="text" name="url4" value="http://docs.cloudscripting.com"></td> 
                </tr>   
                <tr>    
                <td>Description4: </td>
                <td><input type="text" name="description4" value="Cloud Scripting"></td> 
                </tr>   
        </table>
	</td>
	<td>
	<table>
		<tr>
		<td>Title5: </td>
		<td><input type="text" name="title5" value="Jelastic JPS"></td>
		</tr>
                <tr>    
                <td>Url5: </td>
                <td><input type="text" name="url5" value="https://github.com/jelastic-jps"></td> 
                </tr>   
                <tr>    
                <td>Description5: </td>
                <td><input type="text" name="description5" value="Github repository"></td> 
                </tr>   
        </table>
        </td>
        </tr>
	</table>
            <br><tr><input type="submit" name="submit" value="Replace"></tr>
	</form>
	</center>

	
    </body>
</html>

EOF

#Rewrites Controller to recreate table before insert new data
cat << EOF > $mypath/app/Http/Controllers/Controller.php
<?php

namespace App\\Http\\Controllers;
use Illuminate\\Foundation\\Bus\\DispatchesJobs;
use Illuminate\\Routing\\Controller as BaseController;
use Illuminate\\Foundation\\Validation\\ValidatesRequests;
use Illuminate\\Foundation\\Auth\\Access\\AuthorizesRequests;
use Illuminate\\Http\\Request;
use DB;

class Controller extends BaseController
{
    use AuthorizesRequests, DispatchesJobs, ValidatesRequests;
	function insert(Request \$req)
	{
		\$title1 = \$req->input('title1');
		\$url1 = \$req->input('url1');
		\$description1 = \$req->input('description1');
		
		\$title2 = \$req->input('title2');
		\$url2 = \$req->input('url2');
		\$description2 = \$req->input('description2');
		
		\$title3 = \$req->input('title3');
		\$url3 = \$req->input('url3');
		\$description3 = \$req->input('description3');
		
		\$title4 = \$req->input('title4');
		\$url4 = \$req->input('url4');
		\$description4 = \$req->input('description4');
		
		\$title5 = \$req->input('title5');
		\$url5 = \$req->input('url5');
		\$description5 = \$req->input('description5');

DB::table("$tablename")->delete();
		\$data1 = array("title"=>\$title1,"url"=>\$url1,"description"=>\$description1);
		DB::table("$tablename")->insert(\$data1);
		\$data2 = array("title"=>\$title2,"url"=>\$url2,"description"=>\$description2);
		DB::table("$tablename")->insert(\$data2);
		\$data3 = array("title"=>\$title3,"url"=>\$url3,"description"=>\$description3);
		DB::table("$tablename")->insert(\$data3);
		\$data4 = array("title"=>\$title4,"url"=>\$url4,"description"=>\$description4);
		DB::table("$tablename")->insert(\$data4);
		\$data5 = array("title"=>\$title5,"url"=>\$url5,"description"=>\$description5);
		DB::table("$tablename")->insert(\$data5);

		   return redirect('/');
	}
}


EOF

#Adds "Replace" link to the welcome page that leads to Insert Form
sed -i "s| \+Laravel|\tLaravel\n\t</div><a href=\"..\/public\/submit\"><font color=\"red\"><h2>Replace links</h2><\/font><\/a>\n\t\t<div><br>|g" $mypath/resources/views/welcome.blade.php

echo
echo -e "Open in browser \\033[1;32m\033[1mhttp://${HOSTNAME}/$proj/public\033[0m\\033[0;39m "
echo


