xquery version "3.1";

module namespace client-post="http://gawati.org/xq/client-db/services/post";

import module namespace rest = "http://exquery.org/ns/restxq";
import module namespace sm = "http://exist-db.org/xquery/securitymanager";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
import module namespace store="http://gawati.org/1.0/client/store" at "../modules/store.xqm";
declare namespace gwd="http://gawati.org/ns/1.0/data";

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
: Returns a JSON object
:
:)
declare
    %rest:POST("{$json}")
    %rest:path("/gwdc/document/load")
    %rest:consumes("application/json")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")  
function client-post:get-json($json) {
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

(:~
:
: Returns a full XML Document wrapped in a gwd:package
: Returns the actual XML 
:)
declare
    %rest:POST("{$json}")
    %rest:path("/gwdc/document/load/xml")
    %rest:consumes("application/json")
    %rest:produces("application/xml", "text/xml")
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

(:~
:
: Checks if a document exists
:
:)
declare
    %rest:POST("{$json}")
    %rest:path("/gwdc/document/exists")
    %rest:consumes("application/json")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")  
function client-post:exists-xml($json) {
   let $data := parse-json(util:base64-decode($json))
   return
    try {
        let $iri := $data?iri
        let $doc-exists := store:exists-doc($iri)
        return 
            if ($doc-exists eq true()) then 
              <return>
                <success code="doc_found" message="document found" />
              </return>
            else
              <return>
                <error code="doc_not_found" message="document not found" />
              </return>
    } catch * {
        <return>
            <error code="sys_err_{$err:code}" message="Caught error {$err:code}: {$err:description}" />
        </return>
    }
};

declare
    %rest:POST("{$json}")
    %rest:path("/gwdc/document/permissions")
    %rest:consumes("application/json")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")  
function client-post:document-permissions($json) {
   let $data := parse-json(util:base64-decode($json))
   return
    try {
        let $iri := $data?iri
        let $doc := store:get-doc($iri)
        return 
            if (count($doc) gt 0) then 
               $doc/gwd:permissions
            else
              <return>
                <error code="doc_not_found" message="document not found" />
              </return>
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
        let $roles := $data?roles
        let $map-docs := store:get-docs($docTypes, xs:integer($count), xs:integer($from), $roles)
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
    %rest:path("/gwdc/documents/filter")
    %rest:consumes("application/json")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")  
function client-post:get-filtered-documents($json) {
   let $data := parse-json(util:base64-decode($json))
   return
    try {
        let $docTypes := $data?docTypes
        let $count := $data?pageSize
        let $from := $data?itemsFrom
        let $roles := $data?roles
        let $title := $data?title
        let $docType := $data?docType
        let $subType := $data?subType
        let $fromDate := $data?fromDate
        let $toDate := $data?toDate
        (:let $status := $data?status:)
        let $map-docs := store:get-filtered-docs($docTypes, xs:integer($count), xs:integer($from), $roles, 
                                                 xs:string($title),$docType,$subType,xs:string($fromDate),
                                                 xs:string($toDate))
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
    %rest:path("/gwdc/document/delete")
    %rest:consumes("application/json")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")  
function client-post:delete-document($json) {
   let $data := parse-json(util:base64-decode($json))
   let $exprIriThis := $data?iri
   let $del-doc := store:delete-doc($exprIriThis)
   return $del-doc
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

(:
: {
:    "docIri": "/akn/ke/act/legge/1970-06-03/Cap_44/eng@/!main",
:    "attachments": [
        { 
            index: 1,
            showAs: 'AIF PROJECT',
            iriThis: '/akn/ke/act/legge/1970-06-03/Cap_44/eng@/!main_1',
            origFileName: '2015-10-28 09_57_44-Greenshot.png',
            fileName: 'akn_ke_act_legge_1970-06-03_Cap_44_eng_main_1.png',
            fileType: '.png',
            type: 'embedded' 
        },
        { 
            index: 2,
            showAs: 'DC',
            iriThis: '/akn/ke/act/legge/1970-06-03/Cap_44/eng@/!main_2',
            origFileName: '8SRFPv2.doc',
            fileName: 'akn_ke_act_legge_1970-06-03_Cap_44_eng_main_2.doc',
            fileType: '.doc',
            type: 'embedded' 
        }
        ]
:  }
:
:
:
:)
declare
    %rest:POST("{$json}")
    %rest:path("/gwdc/document/attachments")
    %rest:consumes("application/json")
    %rest:produces("application/json")
    %output:media-type("application/json")
    %output:method("json")   
function client-post:attachments($json) {
    let $obj := parse-json(util:base64-decode($json))
    let $doc-iri := $obj?docIri
    let $ret := store:save-attachments($doc-iri, $obj?attachments) 
    return $ret
};
