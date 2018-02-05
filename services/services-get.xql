xquery version "3.1";

module namespace client-get="http://gawati.org/xq/client-db/services/get";

import module namespace rest = "http://exquery.org/ns/restxq";
import module namespace sm = "http://exist-db.org/xquery/securitymanager";

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
