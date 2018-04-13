xquery version "3.1";

module namespace client-get="http://gawati.org/xq/client-db/services/get";

import module namespace rest = "http://exquery.org/ns/restxq";
import module namespace sm = "http://exist-db.org/xquery/securitymanager";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace pkg="http://expath.org/ns/pkg";

import module namespace config="http://gawati.org/client-data/config" at "../modules/config.xqm";
import module namespace store = "http://gawati.org/1.0/client/store" at "../modules/store.xqm";


declare 
    %rest:GET
    %rest:path("/test")
function client-get:test() {
    <xml />
 };

declare
    %rest:GET
    %rest:path("/sec-test")
function client-get:sec-test() {
    <sec-test>
        <before-login>{sm:id()}</before-login>
        <after-login>{
            let $success := xmldb:login("/db", "admin", "")
            return
                if($success) then
                    sm:id()
                else
                    <failed-login/>
        }</after-login>
        <after-logout>{
            let $success := xmldb:login("/db", "guest", "guest")
            return
                if($success) then
                    sm:id()
                else
                    <failed-logout/>
        }</after-logout>
    </sec-test>
};

(:~
 : This is provided just to check if the RestXQ services are functioning
 : @returns XHTML document index.xml from the database
 :)
declare
    %rest:GET
    %rest:path("/gwdc/about")
    %rest:produces("text/plain")
    %output:media-type("text/plain")
    %output:method("text")    
function client-get:about() {
    let $doc := doc($config:app-root || "/expath-pkg.xml")
    return
    "package=" || data($doc/pkg:package/@abbrev) || ";" || "version=" ||  data($doc/pkg:package/@version) || ";date=" || data($doc/pkg:package/@date) 
};
