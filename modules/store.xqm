module namespace store="http://gawati.org/1.0/client/store";

declare namespace xmldb="http://exist-db.org/xquery/xmldb";
declare namespace util="http://exist-db.org/xquery/util";
 
declare namespace cfgx="http://gawati.org/client/config";
declare namespace an="http://docs.oasis-open.org/legaldocml/ns/akn/3.0";
declare namespace gwd="http://gawati.org/ns/1.0/data";
declare namespace gw="http://gawati.org/ns/1.0";
declare namespace ftfile="http://gawati.org/ns/1.0/content/pdf";

import module namespace functx="http://www.functx.com" at "./functx.xql" ;
import module namespace config="http://gawati.org/client-data/config" at "./config.xqm";
import module namespace andoc="http://exist-db.org/xquery/apps/akomantoso30" at "./akomantoso.xql";
import module namespace utils="http://gawati.org/1.0/client/utils" at "./utils.xql" ;
import module namespace docrewrite="http://gawati.org/1.0/client/docrewrite" at "./docrewrite.xql";
import module namespace dbauth="http://gawati.org/1.0/client/dbauth" at "./dbauth.xql";

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
 : Save the metadata) 
 :)
declare function store:save-metadata($doc-iri as xs:string, $json-metadata) {
    (: generate the new classification node :)
    let $classification-node := local:metadata-rewrite-classification($json-metadata)
    (: get the existing document from the database :)
    let $doc := store:get-doc($doc-iri)
    (: build a map of nodes to rewrite :)
    let $switch-map := map {
        "classifications" := $classification-node
    }
    (: create a new document based on the map :)
    let $rewritten-doc := docrewrite:rewriter($doc, $switch-map)
    (: Get file name for the doc :)
    let $file-xml := util:document-name($doc)
    (: write rewritten doc to the database:)
    return store:save-doc($doc-iri, $rewritten-doc, $file-xml) 
};

(: 
!+(AH, 2018-07-03) - make source configurable
:)
declare function local:metadata-rewrite-classification($json-metadata) {
   <an:classification source="#editor">{
      for $entry in $json-metadata?*
        return
            <an:keyword eId="ontology.dictionary.gawati.editor.{$entry?value}" 
                        value="{$entry?value}"
                        showAs="{$entry?showAs}"
                        dictionary="#gawati-editor"/>
    } </an:classification>
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
            <gwd:permission name="{$entry?name}">
                <gwd:roles> {
                  for $role-entry in $entry?roles?*
                  return
                    <gwd:role name="{$role-entry}" />
                }</gwd:roles>
            </gwd:permission>
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

declare function store:get-metadata() {
    let $s-map := config:storage-info()
    let $docs := collection($s-map("path"))//an:akomaNtoso
    return
    <metadata source="{$s-map("path")}">
    {
    for $kw in $docs//an:classification/an:keyword
        let $kw-shows := $kw/@showAs
        group by $kwv := data($kw/@value)
        order by $kwv ascending
        return <keyword value="{$kwv}" >{$kw-shows[1]}</keyword>
     }
     </metadata>  
};

declare function store:delete-doc($exprIriThis as xs:string) {  
    let $s-map := config:storage-info()
    let $collection := $s-map("db-path")
    let $doc : = store:get-doc($exprIriThis)
    let $doc-store := $doc
    let $log-in := dbauth:login()
    return
        if ($log-in) then
        let $del-doc := xmldb:remove(util:collection-name($doc),util:document-name($doc))
        return <return>
                <success message="file deleted successfully" />
             </return>
        else <return>
                <error message="authentication failed" />
             </return>  
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

declare function store:get-filtered-docs($type as xs:string, $count as xs:integer, $from as xs:integer, 
                                         $roles as array(xs:string), $title as xs:string,$docType as array(xs:string),
                                         $subType as array(xs:string),$fromDate as xs:string,$toDate as xs:string) {
    let $s-map := config:storage-info()
    let $docs := collection($s-map("path"))//an:akomaNtoso/ancestor::node()
    let $filtered-docs := store:filter-docs-listing($docs, $roles)
  
    let $doc1-match := $filtered-docs//an:akomaNtoso/an:*/an:meta/an:publication[contains(@showAs | @name,$title)]/ancestor::node()                
    let $docs1 := 
        if($title != '')
        then 
            if ($doc1-match)
            then $doc1-match//an:akomaNtoso/ancestor::node()
            else ()
        else $filtered-docs//an:akomaNtoso/ancestor::node()
      
    let $doc2-match := $docs1//an:akomaNtoso/an:*[local-name() = $docType][@name = $subType]/ancestor::node()

(: if localTypeName is checked in the UI, then $docType(=aknType) and $subType(=localTypeNameNormalized) both would be present
:  else none of them would be present so we can just use one of them in the if condition
:)
    let $docs2 := 
        if($subType != '')
        then
            if ($doc2-match)
            then $doc2-match//an:akomaNtoso/ancestor::node()
            else ()
        else $docs1//an:akomaNtoso/ancestor::node()

    let $doc3-match := $docs2//an:FRBRExpression/an:FRBRdate[(xs:date(@date)>=xs:date($fromDate))]/ancestor::node()
    let $docs3 :=
        if ($doc3-match)
        then $doc3-match//an:akomaNtoso/ancestor::node()
        else ()
     
    let $doc4-match := $docs3//an:FRBRExpression/an:FRBRdate[(xs:date(@date)<=xs:date($toDate))]/ancestor::node()
    let $docs4 :=
        if ($doc4-match)
        then $doc4-match//an:akomaNtoso/ancestor::node()
        else ()
     
(:  let $doc5-match := $docs4//gwd:workflow/gwd:state[@status = $status]/ancestor::node()
    let $docs5 := 
        if($status != '')
        then
            if ($doc5-match)
            then $doc5-match
            else ()
        else $docs4//gwd:workflow/ancestor::node()
:)    
    let $total-docs := count($docs4)
    return map {
         "records" := $total-docs,
         "pageSize" := $count,
         "itemsFrom" := $from,                    
         "totalPages" := ceiling($total-docs div $count) ,
         "currentPage" := xs:integer($from div $count) + 1,    
         "data" := subsequence($docs4, $from, $count)
        }
};

declare function store:save-doc($iri as xs:string, $doc as item()*, $file-xml as xs:string) {
    let $s-map := config:storage-info()
    (: get akn prefixed sub-path :)
    let $db-path := utils:iri-upto-date-part($iri)
    let $log-in := dbauth:login()
    return
        if ($log-in) then
            (: attempt to create the collection, it will return without creating if the collection
            already exists :)
            let $newcol := xmldb:create-collection($s-map("db-path"), $db-path)
            (: store the xml document :)
            let $stored := xmldb:store($s-map("db-path") || $db-path, $file-xml, $doc)
            let $logout := dbauth:logout()
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
        <entry key="tags">
            <update>update value $doc//an:tags with $update-value</update>
        </entry>
    </updateMap>
;

declare function store:update-doc($iri as xs:string, $data as array(*)) {
    try {
        let $log-in := dbauth:login()
        return
            if ($log-in) then
                 let $doc := store:get-doc($iri)
                 let $logout := dbauth:logout()
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

declare function store:get-tags($iri as xs:string) {
    let $doc := store:get-doc($iri)
    let $meta-tags := string-join(data($doc//@showAs[not (.="")]), ",")
    
    let $ft-iri := functx:replace-first($iri, '/akn', '/akn_ft')
    let $ft-path := utils:iri-upto-date-part($ft-iri)
    
    let $s-map := config:storage-info()
    let $ft-docs := collection(concat($s-map("path"), $ft-path))
    let $ft-tags := string-join(data($ft-docs//ftfile:pages//ftfile:tags), ",")
    
    let $s := concat($meta-tags, ",", $ft-tags) 
    return distinct-values(tokenize($s, ","))
};

declare function store:refresh-tags($iri as xs:string) {
    try {
        let $log-in := dbauth:login()
        return
            if ($log-in) then
                 let $doc := store:get-doc($iri)
                 let $tags := store:get-tags($iri)
                 let $logout := dbauth:logout()
                 return
                    if (count($tags) gt 0) then
                       <return>
                        <success code="Tags Refreshed" message="Tags refreshed">
                           {
                            let $update-key := 'tags'
                            let $update-value := string-join($tags, ",")
                            let $update-config := $store:UPDATE_MAP/entry[@key = $update-key]  
                            let $update-qry :=  data($update-config/update)
                            return
                             <success code="tags_refreshed" key="{$update-key}"> 
                                {
                                        util:eval(
                                           $update-qry
                                        )
                               }
                              </success>
                           } 
                      </success>
                     </return>
                    else
                      <return>
                        <error code="tags_not_found" message="Tags not found" />
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