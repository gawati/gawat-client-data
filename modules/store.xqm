module namespace store="http://gawati.org/1.0/client/store";

declare namespace xmldb="http://exist-db.org/xquery/xmldb";
 declare namespace util="http://exist-db.org/xquery/util";
 
declare namespace cfgx="http://gawati.org/client/config";
declare namespace an="http://docs.oasis-open.org/legaldocml/ns/akn/3.0";
declare namespace gwd="http://gawati.org/ns/1.0/data";
declare namespace gw="http://gawati.org/ns/1.0";

import module namespace functx="http://www.functx.com" at "./functx.xql" ;
import module namespace config="http://gawati.org/client-data/config" at "./config.xqm";
import module namespace andoc="http://exist-db.org/xquery/apps/akomantoso30" at "./akomantoso.xql";
import module namespace utils="http://gawati.org/1.0/client/utils" at "./utils.xql" ;
import module namespace docrewrite="http://gawati.org/1.0/client/docrewrite" at "./docrewrite.xql";

(:
 : Save the attachments in the document. Saving involves rewriting the current set of attachments in the <embeddedContents> element
 : Writing the new <book> node with updated componentRef information for each attachment, into the document.
 : $obj?attachments) 
 :)
declare function store:save-attachments($doc-iri as xs:string, $json-attachments) {
    (: generate the new embeddedContents node :)
    let $embeddedContents-node := local:attachments-rewrite-embeddedContents($json-attachments)
    (: generate the new book node :)
    let $book-node := local:attachments-rewrite-book($json-attachments)
    (: get the existing document from the database :)
    let $doc := store:get-doc($doc-iri)
    (: build a map of nodes to rewrite :)
    let $switch-map := map {
        "embeddedContents" := $embeddedContents-node,
        "book" := $book-node
    }
    (: create a new document based on the map :)
    let $rewritten-doc := docrewrite:rewriter($doc, $switch-map)
    (: Get file name for the doc :)
    let $doc := store:get-doc($doc-iri)
    let $file-xml := util:document-name($doc)
    (: write rewritten doc to the database:)
    return store:save-doc($doc-iri, $rewritten-doc, $file-xml) 
};

declare function local:attachments-rewrite-embeddedContents($json-attachments) {
    <gw:embeddedContents> {
      for $entry in $json-attachments?*
        return
            <an:embeddedContent eId="embedded-doc-{$entry?index}"
                                type="{$entry?type}" 
                                fileType="{$entry?fileType}" 
                                file="{$entry?fileName}" 
                                origFileName="{$entry?origFileName}" 
                                state="true" />
    } </gw:embeddedContents>
};

declare function local:attachments-rewrite-book($json-attachments) {
    <an:book refersTo="#mainDocument"> {
      for $entry in $json-attachments?*
        return
            <an:componentRef src="{$entry?iriThis}" 
                             alt="{$entry?origFileName}" 
                             GUID="#embedded-doc-{$entry?index}" 
                             showAs="{$entry?showAs}" />
    } </an:book>
};


(:
 : Transit the document from one state to another. Transiting involves rewriting the current state in the <workflow> element
 : Writing new permission information into the document based on the state.
 : Writing new modified dates into the document
 : $obj?state?permission) 
 :)
declare function store:transit-document($doc-iri as xs:string, $file-xml as xs:string, $state-name as xs:string, $state-label as xs:string, $json-permission) {
    (: generate the new permissions node :)
    let $permissions-node := local:transit-rewrite-permissions($json-permission)
    (: generate the new workflow node :)
    let $workflow-node := local:transit-rewrite-workflow($state-name, $state-label)
    (: get the existing document from the database :)
    let $doc := store:get-doc($doc-iri)
    (: build a map of nodes to rewrite :)
    let $switch-map := map {
        "workflow" := $workflow-node,
        "permissions" := $permissions-node
    }
    (: create a new document based on the map :)
    let $rewritten-doc := docrewrite:rewriter($doc, $switch-map)
    (: write rewritten doc to the database:)
    return store:save-doc($doc-iri, $rewritten-doc, $file-xml) 
};

declare function local:transit-rewrite-workflow($state-name as xs:string, $state-label as xs:string) {
    <gwd:workflow>
        <gwd:state status="{$state-name}" label="{$state-label}" />
    </gwd:workflow>
};


declare function local:transit-rewrite-permissions($json-permission) {
    <gwd:permissions> {
      for $entry in $json-permission?*
        return
            <permission name="{$entry?name}">
                <roles> {
                  for $role-entry in $entry?roles?*
                  return
                    <role name="{$role-entry}" />
                }</roles>
            </permission>
    } </gwd:permissions>
};

declare function store:exists-doc($exprIriThis as xs:string) {
    let $s-map := config:storage-info()
    let $docs := collection($s-map("path"))//an:akomaNtoso[
        ./an:*/an:meta/an:identification/an:FRBRExpression/an:FRBRthis[
            @value eq $exprIriThis
            ]
        ]
    return
        count($docs) gt 0
};

declare function store:get-doc($exprIriThis as xs:string) {
    let $s-map := config:storage-info()
    let $doc := collection($s-map("path"))//an:akomaNtoso[
        ./an:*/an:meta/an:identification/an:FRBRExpression/an:FRBRthis[
            @value eq $exprIriThis
            ]
        ]/ancestor::node()
    return $doc
};


declare function store:get-docs($type as xs:string, $count as xs:integer, $from as xs:integer) {
    let $s-map := config:storage-info()
    let $docs := collection($s-map("path"))//an:akomaNtoso/ancestor::node()
    let $total-docs := count($docs)
    return map {
         "records" := $total-docs,
         "pageSize" := $count,
         "itemsFrom" := $from,                    
         "totalPages" := ceiling($total-docs div $count) ,
         "currentPage" := xs:integer($from div $count) + 1,    
         "data" := subsequence($docs, $from, $count)
        }
};


declare function store:save-doc($iri as xs:string, $doc as item()*, $file-xml as xs:string) {
    let $s-map := config:storage-info()
    (: get akn prefixed sub-path :)
    let $db-path := utils:iri-upto-date-part($iri)
    let $log-in := xmldb:login($s-map("db-path"), $s-map("user"), "gawati-client-data")
    return
        if ($log-in) then
            (: attempt to create the collection, it will return without creating if the collection
            already exists :)
            let $newcol := xmldb:create-collection($s-map("db-path"), $db-path)
            (: store the xml document :)
            let $stored := xmldb:store($s-map("db-path") || $db-path, $file-xml, $doc)
            return
            if (empty($stored)) then
               <return>
                    <error code="save_file_failed" message="error while saving file" />
               </return>
            else
               <return>
                    <success code="save_file" message="{$stored}" />
               </return>     
        else
            <return>
                <error code="save_login_failed" message="login to save collection failed" />
            </return>
};

declare variable $store:UPDATE_MAP := 
    <updateMap>
        <entry key="docTitle">
            <update>update value $doc//an:publication/@showAs with $update-value</update>
        </entry>
    </updateMap>
;

declare function store:update-doc($iri as xs:string, $data as array(*)) {
    let $s-map := config:storage-info()
    return
        try {
            let $log-in := xmldb:login($s-map("db-path"), $s-map("user"), "gawati-client-data")
            return
                if ($log-in) then
                     let $doc := store:get-doc($iri)
                     return
                        if (count($doc) gt 0) then
                           <return>
                            <success code="File Updated" message="files updated">
                               {
                                let $ret :=  array:for-each(
                                        $data, 
                                        function($item) {
                                            let $update-key :=    $item?name
                                            let $update-value :=    $item?value
                                            let $update-config := $store:UPDATE_MAP/entry[@key = $update-key]  
                                            let $update-qry :=  data($update-config/update)
                                            return
                                             <success code="file_updated" key="{$update-key}"> 
                                                {
                                                        util:eval(
                                                           $update-qry
                                                        )
                                               }
                                              </success>
                                        }
                                   )
                                return $ret
                              } 
                          </success>
                         </return>
                        else
                          <return>
                            <error code="document_to_update_not_found" message="Document to update was not found" />
                          </return>
               else
                <return>
                    <error code="failed_to_authenticate_with_store" message="Unable to authenticate with storage" />
                </return>
        } catch * {
            <return>
                <error code="sys_err_{$err:code}" message="Caught error {$err:code}: {$err:description}" />
            </return>
        }
};

