xquery version "3.1";

import module namespace client-post="http://gawati.org/xq/client-db/services/post" at "../services/services-post.xql";
import module namespace store="http://gawati.org/1.0/client/store" at "../modules/store.xqm";

import module namespace config="http://gawati.org/client-data/config";

client-post:delete-documents('{"iri":"/akn/tz/judgment/courtjudgment/2018-04-18/ssss/afr@/!main"}')
