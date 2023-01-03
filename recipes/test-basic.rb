rest 'http://localhost:8080/'

rest 'just-do-it' do
  url 'http://localhost:8080/'
end

rest 'only-if-1-should-be-up-to-date' do
  url 'http://localhost:8080/'
  only_if_REST ({ url: 'http://localhost:8080/404' })
end

rest 'only-if-2-should-converge' do
  url 'http://localhost:8080/'
  only_if_REST ({ url: 'http://localhost:8080/404', ok_codes: [404, '20[012'] })
end

rest 'not-if-1-should-converge' do
  url 'http://localhost:8080/'
  not_if_REST ({ url: 'http://localhost:8080/404' })
end

rest 'not-if-2-should-be-up-to-date' do
  url 'http://localhost:8080/'
  not_if_REST ({ url: 'http://localhost:8080/404', ok_codes: [404, '20[012'] })
end

rest 'url-with-semicolon-any-error?' do
  url 'http://localhost:8080/foo;bar.txt'
end
