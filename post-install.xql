xquery version "3.0";

import module namespace xdb="http://exist-db.org/xquery/xmldb";

import module namespace util="http://exist-db.org/xquery/util";
import module namespace console="http://exist-db.org/xquery/console";

(: The following external variables are set by the repo:deploy function :)

(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

declare variable $my-user := "gawati-client-data" ;

declare function local:change-password() {
    let $pw := replace(util:uuid(), "-", "")
    let $ret := xdb:change-user($my-user, $pw, ($my-user))
    return $pw
};

declare function local:mkcol-recursive($collection, $components) {
    if (exists($components)) then
        let $newColl := concat($collection, "/", $components[1])
        return (
            xdb:create-collection($collection, $components[1]),
            local:mkcol-recursive($newColl, subsequence($components, 2))
        )
    else
        ()
};

(: Helper function to recursively create a collection hierarchy. :)
declare function local:mkcol($collection, $path) {
    local:mkcol-recursive($collection, tokenize($path, "/"))
};


let $f := local:mkcol("/db", "docs")
let $f2 := local:mkcol("/db/docs", $my-user)
let $f3  := xdb:set-collection-permissions("/db/docs/" || $my-user , $my-user, $my-user,  util:base-to-integer(0755, 8) )

let $pw := local:change-password()

let $login := xdb:login($target, $my-user, $pw)

let $ret := 
    <users>
        <user name="{$my-user}" pw="{$pw}" />
    </users>
    
let $r := xdb:store($target || "/_auth", "_pw.xml", $ret) 
(: store the collection configuration :)
return $r