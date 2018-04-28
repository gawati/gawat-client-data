xquery version "3.1";

module namespace client-post="http://gawati.org/xq/client-db/services/post";

import module namespace rest = "http://exquery.org/ns/restxq";
import module namespace sm = "http://exist-db.org/xquery/securitymanager";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
import module namespace store="http://gawati.org/1.0/client/store" at "../modules/store.xqm";

declare
    %rest:POST("{$json}")
    %rest:path("/gwdc/document/add")
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

declare function local:wrap-package($map-docs, $count as xs:integer, $from as xs:integer) {
   <gwd:packageListing  
        timestamp="{current-dateTime()}" 
        records="{$map-docs("records")}"
        pageSize="{$count}"
        itemsFrom="{$from}"
        currentPage="{$map-docs('currentPage')}"
        xmlns:gwd="http://gawati.org/ns/1.0/data">
        {$map-docs("data")}
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
    %rest:path("/gwdc/document/load")
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
    %rest:path("/gwdc/documents")
    %rest:consumes("application/json")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")  
function client-post:get-documents($json) {
   let $data := parse-json(util:base64-decode($json))
   return
    try {
        let $docTypes := $data?docTypes
        let $count := $data?pageSize
        let $from := $data?itemsFrom
        let $map-docs := store:get-docs($docTypes, xs:integer($count), xs:integer($from))
        return 
            if (count($map-docs("data")) eq 0) then 
              <return>
                <error code="docs_not_found" message="documents not found" />
              </return>
            else
              local:wrap-package($map-docs, xs:integer($count), xs:integer($from))
    } catch * {
        <return>
            <error code="sys_err_{$err:code}" message="Caught error {$err:code}: {$err:description}" />
        </return>
    }
};



declare
    %rest:POST("{$json}")
    %rest:path("/gwdc/document/edit")
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

(:
: {
:    "aknType": "act",
:    "aknSubType": "legge",
:    "state": {
:        "name": "editable",
:        "title": "Editable",
:        "level": "2",
:        "color": "initial",
:        "permission": [
:            {
:                "name": "view",
:                "roles": "client.Admin client.Editor"
:            },
:            ...
:            ]
:         }
:  }
:
:
:
:)
declare
    %rest:POST("{$json}")
    %rest:path("/gwdc/document/transit")
    %rest:consumes("application/json")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")  
function client-post:transit($json) {
    let $obj := parse-json(util:base64-decode($json))
    let $state-name := $obj?state?name
    let $state-label := $obj?state?title
    let $doc-iri := $obj?docIri
    let $ret := store:transit-document($doc-iri, $state-name, $state-label, $obj?state?permission)
    return $ret
};
