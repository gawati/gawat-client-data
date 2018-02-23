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
        let $update := $data?update
        let $file-xml := $data?fileXml
        let $exists := store:exists-doc($iri)
        return 
            if ($exists and $update ne true()) then 
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

declare function local:wrap-package($doc) {
   <gwd:packageListing  
        timestamp="{current-dateTime()}" 
        xmlns:gwd="http://gawati.org/ns/1.0/data">
        {$doc}
    </gwd:packageListing>
};

(:~
:
: Returns a full XML Document wrapped in a gwd:package
:
:
:)
declare
    %rest:POST("{$json}")
    %rest:path("/getXml")
    %rest:consumes("application/json")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")  
function client-post:get-xml($json) {
   let $data := parse-json(util:base64-decode($json))
   return
    try {
        let $iri := $data?iri
        let $doc := store:get-doc($iri)
        return 
            if (count($doc) eq 0) then 
              <return>
                <error code="doc_not_found" message="document not found" />
              </return>
            else
              $doc
    } catch * {
        <return>
            <error code="sys_err_{$err:code}" message="Caught error {$err:code}: {$err:description}" />
        </return>
    }
};


declare
    %rest:POST("{$json}")
    %rest:path("/getDocuments")
    %rest:consumes("application/json")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")  
function client-post:get-documents($json) {
   let $data := parse-json(util:base64-decode($json))
   return
    try {
        let $docTypes := $data?docTypes
        let $docs := store:get-docs($docTypes)
        return 
            if (count($docs) eq 0) then 
              <return>
                <error code="docs_not_found" message="documents not found" />
              </return>
            else
              local:wrap-package($docs)
    } catch * {
        <return>
            <error code="sys_err_{$err:code}" message="Caught error {$err:code}: {$err:description}" />
        </return>
    }
};



declare
    %rest:POST("{$json}")
    %rest:path("/updateXml")
    %rest:consumes("application/json")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")  
function client-post:update-xml($json) {
    (:
    {data: [{name="docTitle", value="" } ] }
    :)
    let $obj := parse-json(util:base64-decode($json))
    return store:update-doc($obj?iri, $obj?data)
};

