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
declare function store:transit-document($doc-iri as xs:string, $state-name as xs:string, $state-label as xs:string, $json-permission) {
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
    (: Get file name for the doc :)
    let $file-xml := util:document-name($doc)
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

declare function store:exists-doc($exprIriThis as xs:string) {
    let $s-map := config:storage-info()
    let $doc := collection($s-map("path"))//an:akomaNtoso[
        ./an:*/an:meta/an:identification/an:FRBRExpression/an:FRBRthis[
            @value eq $exprIriThis
            ]
        ]/ancestor::node()
    return 
        if (count($doc) gt 0) then 
            true() 
        else 
            false()
};

(:
 : Checks if any of the client roles are there in any of the tier's roles
 : for the given document.
:)
declare function store:role-exists($doc, $tier, $client-roles) {
    let $doc-roles := $doc/gwd:permissions/gwd:permission[contains($tier,@name)]/gwd:roles/gwd:role/@name
    let $common-roles := functx:value-intersect($client-roles, $doc-roles)
    return count($common-roles) > 0
};

(:
 : Listing permissions are checked based on a hierarchy of permissions.
 : If the client role has any of the 3 tiers of permissions specified in the document, 
 : that document can be listed.
 : Further actions are determined by permissions 
:)
declare function store:is-listing-permitted($doc, $client-roles) {
  let $tier-1 := ('transit', 'delete', 'edit')
  let $tier-2 := ('view')
  let $tier-3 := ('list')
  
  return
  if (store:role-exists($doc, $tier-1, $client-roles) or 
      store:role-exists($doc, $tier-2, $client-roles) or
      store:role-exists($doc, $tier-3, $client-roles)) then
      true()
  else
      false()
};

(:
 : Filter documents that are permissible to list for the client based on client roles.
:)
declare function store:filter-docs-listing($docs, $client-roles) {
    for $doc in $docs
    where store:is-listing-permitted($doc, $client-roles)
    return $doc   
};

declare function store:get-docs($type as xs:string, $count as xs:integer, $from as xs:integer, $roles as array(xs:string)) {
    let $s-map := config:storage-info()
    let $docs := collection($s-map("path"))//an:akomaNtoso/ancestor::node()
    
    let $filtered-docs := store:filter-docs-listing($docs, $roles)
    let $total-docs := count($filtered-docs)
    
    return map {
         "records" := $total-docs,
         "pageSize" := $count,
         "itemsFrom" := $from,                    
         "totalPages" := ceiling($total-docs div $count) ,
         "currentPage" := xs:integer($from div $count) + 1,    
         "data" := subsequence($filtered-docs, $from, $count)
        }
};

declare function store:get-filtered-docs($type as xs:string, $count as xs:integer, $from as xs:integer, $roles as array(xs:string), $title as xs:string,$docType as xs:string,$fromDate as xs:string,$toDate as xs:string,$status as xs:string) {
    let $s-map := config:storage-info()
    let $docs := collection($s-map("path"))//an:akomaNtoso/ancestor::node()
    let $filtered-docs := store:filter-docs-listing($docs, $roles)

    let $docs1 := 
       if ($filtered-docs//an:akomaNtoso/an:*/an:meta/an:publication[contains(@showAs | @name,$title)]/ancestor::node())
       then $filtered-docs//an:akomaNtoso/an:*/an:meta/an:publication[contains(@showAs | @name,$title)]/ancestor::node()
       else $filtered-docs//an:akomaNtoso/ancestor::node()
    
    let $docs2 := 
       if ($docs1//an:akomaNtoso/an:*[@name eq $docType]/ancestor::node())
       then $docs1//an:akomaNtoso/an:*[@name eq $docType]/ancestor::node()
       else $docs1//an:akomaNtoso/ancestor::node()
    
    let $docs3 :=
        if ($docs2//an:FRBRExpression/an:FRBRdate[(xs:date(@date)>=xs:date($fromDate)) and (xs:date(@date)<=xs:date($toDate))]/ancestor::node())
        then $docs2//an:FRBRExpression/an:FRBRdate[(xs:date(@date)>=xs:date($fromDate)) and (xs:date(@date)<=xs:date($toDate))]/ancestor::node()
        else $docs2//an:akomaNtoso/ancestor::node()
     
    let $docs4 := 
        if ($docs3//gwd:workflow/gwd:state[@status eq $status]/ancestor::node())
        then $docs3//gwd:workflow/gwd:state[@status eq $status]/ancestor::node()
        else $docs3//gwd:workflow/ancestor::node()
    
    let $docs-filtered := $docs1 intersect $docs2 intersect $docs3 intersect $docs4
    let $total-docs := count($docs-filtered)
    return map {
         "records" := $total-docs,
         "pageSize" := $count,
         "itemsFrom" := $from,                    
         "totalPages" := ceiling($total-docs div $count) ,
         "currentPage" := xs:integer($from div $count) + 1,    
         "data" := subsequence($docs-filtered, $from, $count)
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

