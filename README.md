# REST in Chef

... using no gems or non-core ruby things. An external curl executable
will do! (only curl is supported).

This is a resource provider for doing simple REST queries to affect
the state of a system you have to use REST to reach. Elasticsearch
is among these.

NOTE: This is NOT a full resource provider in that it does not model
the state of the system it modifies with the REST calls. It just makes
the calls you set up.  You will need to know the API and if the calls
are not imdepotent you will need to put apropriate guards on the calls
using `only_if`, `not_if`, or indeed `only_if_REST` and `not_if_REST`
which is available for this resource.

## Usage

You will need a working CHEF or CINC server and all the trimmings.

* Unpack this in your cookbooks directory so that the path is
  `cookbooks/rest`.  Upload the rest cookbook: `knife cookbook upload
  rest` to your chef server so it can be used by other cookbooks

* Curl must to be installed on the clients where this resource is
  used.  The rest resource does not install it; you must do something
  like: `package curl` in some recipe yourself.

* In cookbooks that will use rest resources include this in the
  metadata.rb file: `depends rest`

Now your cookbook can use the rest resource.  Here is an example
making a user for the prometheus-elasticsearch-exporter in
elasticsearch:

```
require 'json'

rest 'Set prometheus-elasticsearch-exporter user password' do
  action    :POST
  url       'https://localhost:9200/_security/user/prometheus/'
  basicauth "elastic:#{elasticpw}"
  document  ({ roles: [], password: prometheuspw }.to_json)

  ca        '/etc/elasticsearch/ca-cert.pem'

  ok_string 'created'

  # Only create the user if it does not exist already: IFF 'GET' on the
  # same URL works then user exists.
  # Need to override the document and ok_string as this is not the same
  # for the GET action.
  not_if_REST ({ action: :GET, document: nil, ok_string: nil })
end
```

This will look like this when running:

```
  * rest[Set prometheus-elasticsearch-exporter user password] action POST
    - Converging POST https://localhost:9200/_security/user/prometheus/ query
```

## Resource properties

I think the `rest` resource is quite feature rich - hopefully this
will make it easy to use for any number of applications.

NOTE: The 'rest' resource will, with the help of curl, retrieve the
whole answer document from the queried endpoint.  If the document is
too large for your Virtual/RAM memory then you're out of luck, there
is no provision for handling this gracefully.  So don't query for huge
documents.

### Query setup

* `action HTTP method` One of GET, DELETE, POST, PUT, PATCH
  corresponding to the well known HTTP methods.  Other actions are not
  supported at this time (PRs welcome).  This action will be used as
  the HTTP method of the REST query.  Please see
  https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods for more
  information about HTTP methods.

* `url endpoint`: A string with the full URL of the REST endpoint.

* `basicauth username:password`. If needed. The password must be
  supplied in plaintext.  The resource only supports basic HTTP
  authentication at this time (PRs welcome).

### HTTPs security

If the endpoint does not have a commonly recognized server certificate
curl will not complete the connetion.  You can override this with one
of two options:

* `ca CA file`.  Supply the path to the CA file used to sign the server
  certificate.

* `insecure true`.  Curl will accept any certificate as valid.

The resource does not support client certificates (PRs welcome).

### Query content

For PUT, POST and PATCH queries you will need to supply a document to submit
to the endpoint.

* `content_type MIME-type`. The HTTP Content-Type, the default is
  `application/json`.

* `document string`.  The document to be submitted. Empty by default.
  If sending a JSON document it's usually wisest to set up a
  array/hash in ruby and then use `.to_json` on the result as shown in
  the example above.  In this case you must `require 'json'` too.

Multipart and form submissions are not supported at this time (as
usual: PRs welcome).

For GET and DELETE queries the document must be zero length or nil.

### Query result

Some times you will need to examine the result to see if the operation
you wanted performed was successful.

By default the HTTP result codes 200, 201 and 202 will be considered a
success, but you may override this, and also add conditions.

* `ok_codes '20[012]'` - this is the default setting. Here you can
  supply a integer matching just one result code. A string, as in the
  example, will be interpreted as a regular expression.  You can also
  supply a array of integers and/or strings that are valid HTTP result
  codes: e.g. `[ '20[012]', 400, 418 ]`

Once the HTTP result code is accpted additional tests may be applied:

* `ok_string string` - The string will be looked for in the returned
  document.  In the example above the elasticsearch endpoint will
  return a JSON document, but the resource simply looks for `ok_string
  'created'` as a shortcut.

* `ok_json spec-document` - if the answer has application/json as
  document-type then the spec-document describes a lookup to be
  matched in the answer.

* `fail_json spec-document` - oposite of ok_json, if matched the query
  will be recognized as a failure

The json spec-documents are written as follows:

* Returned document: `{ "result": true }'`: then `ok_json ({ "result":
  true })` will match and be true.

* Returned document: `{ "result": { "value": true } }` then `ok_json
  ({ "result.value": true })` will match and be true.

* Returned document: `{ "result": false }'`: then `ok_json ({ "result":
  false })` will match and be true.

### only_if_REST and not_if_REST guards

These guards can be used to query a endpoint before executing the main
query of the resource.  They are used the same way as `only_if` and
`not_if` that you may be familliar with.

The quards inherits _ALL_ the context from the main resource.

I'll repeat the elasticsearch example from above:

```
rest 'Set prometheus-elasticsearch-exporter user password' do
  action    :POST
  url       'https://localhost:9200/_security/user/prometheus/'
  basicauth "elastic:#{elasticpw}"
  document  ({ roles: [], password: prometheuspw }.to_json)

  ca        '/etc/elasticsearch/ca-cert.pem'

  ok_string 'created'

  # Only create the user if it does not exist already: IFF 'GET' on the
  # same URL works then user exists.
  # Need to override the document and ok_string as this is not the same
  # for the GET action.
  not_if_REST ({ action: :GET, document: nil, ok_string: nil })
end
```

This resource definition will first do a `GET
https://localhost:9200/_security/user/prometheus/` with a empty
document and no ok_string check. If this fails it means that the user
is not defined.  If the user is not defined the main query of `POST
https://localhost:9200/_security/user/prometheus/` is executed with
the given document and ok_string check.  Both queries share all other
settings: The CA, the basic authentication and the URL.

The basic result is that the `elastic` user is only created once, the
first time the rest resource is executed. Each following time the user
already exists.

The `not_if_REST` query only changes these settings, which it in this
case, should not share with the main query:

* GET method to check if the resource (the 'elastic' user) is already
  defined or not

* The document is made empty because GET should not send documents to
  the server

* The ok_string is also emptied because the GET query will not return
  this, merely checking the HTTP result code will be enough to
  determine if the user exists or not.  Noe that there is no setting
  changing the HTTP result code check at all.

In the case of `not_if_REST` the main query will only be executed if
the `not_if_REST` query fails. I.e. the 'elastic' user will only be
created if it does not exist already.

In the case of `only_if_REST` you might use this to test if a user
exists before setting the users password.

You can override *all* the properites of the main resource in these
two guards using Ruby hash syntax for each property.  Thus you may
query a completely different resource with completely different
properties with `only_if_REST` and/or `not_if_REST` before sending the
main query given in the rest resource.

If both guards are defined then `only_if_REST` will be checked first,
and only if this succeeds then `not_if_REST` will be checked second.

## Testing

The tests provides some simple futher examples of usage.  They're all
located in the recipes directory.

This has been tested on debian and ubuntu, the package names and
directories used in the tests are adapted to the nginx package in
debian and ubuntu.

The tests have not been set up with test kitchen or such, but rather
locally on a laptop or VM.

Setup for tests: `chef-client -r 'recipe[rest::test-setup]'`.  This
will set up nginx with various files to run tests against.

Basic HTTP functionality: `chef-client -r 'recipe[rest::test-basic]'`

JSON function tests: `chef-client -r 'recipe[rest::test-json]'`
