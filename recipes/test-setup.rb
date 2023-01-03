package 'nginx'

file '/etc/nginx/sites-enabled/default' do
  content <<~FILE
    server {
       listen 8080 default_server;

       root /var/www/html;

       location /200 {
                return 200;
       }
       location /403 {
                return 403;
       }
    }
  FILE
end

file '/var/www/html/index.html' do
  content ''
end

file '/var/www/html/true.json' do
  content '{ "result": true }'
end

file '/var/www/html/true-value.json' do
  content '{ "result": { "value": true } }'
end

file '/var/www/html/true-array.json' do
  content '{ "result": [true, false, false, true ] }'
end

file '/var/www/html/false.json' do
  content '{ "result": false }'
end

file '/var/www/html/false-value.json' do
  content '{ "result": { "value": false } }'
end

file '/var/www/html/string.json' do
  content '{ "result": "ok-string" }'
end

file '/var/www/html/42.json' do
  content '{ "result": 42 }'
end

file '/var/www/html/ERROR.txt' do
  content 'There is a ERROR here'
end

file '/var/www/html/foo;bar.txt' do
  content 'Does ; trip you up?'
end

file '/var/www/html/justafile.txt' do
  content 'this is just a file'
end
