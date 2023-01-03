rest 'json-ok-converge' do
  url 'http://localhost:8080/true.json'
  ok_json ({ "result": true })
end

rest 'json-value-ok-converge' do
  url 'http://localhost:8080/true-value.json'
  ok_json ({ "result.value": true })
end

rest 'json-false-ok-converge' do
  url 'http://localhost:8080/false.json'
  ok_json ({ "result": false })
end

rest 'json-value-false-ok-converge' do
  url 'http://localhost:8080/false-value.json'
  ok_json ({ "result.value": false })
end

rest 'only-if-json-ok-converge' do
  url 'http://localhost:8080/'
  only_if_REST ({ url: 'http://localhost:8080/true.json', ok_json: { "result": true } })
end

rest 'only-if-json-value-ok-converge' do
  url 'http://localhost:8080/'
  only_if_REST ({ url: 'http://localhost:8080/true-value.json', ok_json: { "result.value": true } })
end

rest 'only-if-json-ok-should-NO-converge' do
  url 'http://localhost:8080/'
  only_if_REST ({ url: 'http://localhost:8080/false.json', ok_json: { "result": true } })
end

rest 'only-if-json-value-ok-should-NO-converge' do
  url 'http://localhost:8080/'
  only_if_REST ({ url: 'http://localhost:8080/false-value.json', ok_json: { "result.value": true } })
end
