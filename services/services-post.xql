xquery version "3.1";

module namespace client-post="http://gawati.org/xq/client-db/services/post";

import module namespace rest = "http://exquery.org/ns/restxq";
import module namespace sm = "http://exist-db.org/xquery/securitymanager";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
import module namespace store="http://gawati.org/1.0/client/store" at "../modules/store.xqm";

declare
    %rest:POST("{$json}")
    %rest:path("/saveXml")
    %rest:consumes("application/json")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")  
function client-post:save-xml($json) {
   let $data := parse-json(util:base64-decode($json))
   return
    try {
        let $doc := util:parse($data?data)
        let $iri := $data?iri
        let $file-xml := $data?fileXml
        let $exists := store:exists-doc($iri)
        return 
            if ($exists) then 
              <return>
                <error code="exists_cannot_overwrite" message="file exists cannot overwrite" />
              </return>
            else
                store:save-doc($iri, $doc, $file-xml)
    } catch * {
        <return>
            <error code="sys_err_{$err:code}" message="Caught error {$err:code}: {$err:description}" />
        </return>
    }
};

