xquery version "3.1";

module namespace client-post="http://gawati.org/xq/client-db/services/post";

import module namespace rest = "http://exquery.org/ns/restxq";
import module namespace sm = "http://exist-db.org/xquery/securitymanager";

declare
    %rest:POST("{$json}")
    %rest:path("/saveXml")
    %rest:consumes("application/json")
    %rest:produces("text/xml")
function client-post:get-xml($json) {
   let $data := parse-json(util:base64-decode($json))
   return
    try {
        util:parse($data?data)
    } catch * {
        <error>Caught error {$err:code}: {$err:description} </error>            
    }
};

