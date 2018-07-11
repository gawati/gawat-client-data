xquery version "3.1";

declare namespace xmldb="http://exist-db.org/xquery/xmldb";
declare namespace util="http://exist-db.org/xquery/util";
declare namespace file="http://exist-db.org/xquery/file";

declare namespace cfgx="http://gawati.org/client/config";
declare namespace an="http://docs.oasis-open.org/legaldocml/ns/akn/3.0";
declare namespace gwd="http://gawati.org/ns/1.0/data";
declare namespace gw="http://gawati.org/ns/1.0";

import module namespace store="http://gawati.org/1.0/client/store" at "./store.xqm";
import module namespace functx="http://www.functx.com" at "./functx.xql" ;
import module namespace config="http://gawati.org/client-data/config" at "./config.xqm";
import module namespace andoc="http://exist-db.org/xquery/apps/akomantoso30" at "./akomantoso.xql";
import module namespace utils="http://gawati.org/1.0/client/utils" at "./utils.xql" ;
import module namespace docrewrite="http://gawati.org/1.0/client/docrewrite" at "./docrewrite.xql";
import module namespace dbauth="http://gawati.org/1.0/client/dbauth" at "./dbauth.xql";
declare namespace ftfile="http://gawati.org/ns/1.0/content/pdf";

import module namespace compression="http://exist-db.org/xquery/compression";
import module namespace response="http://exist-db.org/xquery/response";
import module namespace request="http://exist-db.org/xquery/request";

let $iri := "/akn/ke/act/legge/2018-07-06/Test_tags_2/eng@/!main"
let $s-map := config:storage-info()
let $iri-dir := utils:iri-upto-date-part($iri)

let $dir := concat($s-map("path"), $iri-dir)

let $keyfname := utils:get-filename-from-iri($iri, "public")
let $metafname := utils:get-filename-from-iri($iri, "xml")
let $doc := xmldb:document(concat($dir, "/", $keyfname))

let $db-path := utils:iri-upto-date-part($iri)
let $filename := request:get-uploaded-file-name('file')
let $data := request:get-uploaded-file-data('file')
let $log-in := dbauth:login()
let $store := xmldb:store($s-map("db-path") || $db-path, $keyfname, $data, 'application/octet-stream')

return
<results>
   <message>File {$keyfname} has been stored.</message>
</results>


