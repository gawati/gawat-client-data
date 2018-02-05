module namespace store="http://gawati.org/1.0/client/store";

declare namespace xmldb="http://exist-db.org/xquery/xmldb";

declare namespace cfgx="http://gawati.org/client/config";
declare namespace an="http://docs.oasis-open.org/legaldocml/ns/akn/3.0";

import module namespace functx="http://www.functx.com" at "./functx.xql" ;
import module namespace config="http://gawati.org/client-data/config" at "./config.xqm";
import module namespace andoc="http://exist-db.org/xquery/apps/akomantoso30" at "./akomantoso.xql";
import module namespace utils="http://gawati.org/1.0/client/utils" at "./utils.xql" ;

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
    let $docs := collection($s-map("path"))//an:akomaNtoso[
        ./an:*/an:meta/an:identification/an:FRBRExpression/an:FRBRthis[
            @value eq $exprIriThis
            ]
        ]
    return $docs
};


declare function store:get-docs($type as xs:string) {
    let $s-map := config:storage-info()
    let $docs := collection($s-map("path"))//an:akomaNtoso/ancestor::node()
    return $docs
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

