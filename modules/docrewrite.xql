module namespace docrewrite="http://gawati.org/1.0/client/docrewrite";
declare namespace an="http://docs.oasis-open.org/legaldocml/ns/akn/3.0";
declare namespace gwd="http://gawati.org/ns/1.0/data";
declare namespace gw="http://gawati.org/ns/1.0";


(: <gw:dateTime refersTo="#docCreatedDate" datetime="2018-02-24T01:08:30+05:30"/> :)
(: Rewriter api, pass in a map with the rewritten element :) 
declare function docrewrite:rewriter($nodes as node()*, $switch-map) as item()* {
    for $node in $nodes 
    return
        typeswitch ($node)
            case text() return $node
            case comment() return $node
            case element(gwd:workflow) return local:dispatch-element($node, $switch-map, "workflow")
            case element(gwd:permissions) return local:dispatch-element($node, $switch-map, "permissions")
            case element(gw:dateTime) return local:dispatch-dateTime-handler($node, $switch-map)
            case element(gw:embeddedContents) return local:dispatch-element($node, $switch-map, "embeddedContents")
            case element(an:book) return local:dispatch-element($node, $switch-map, "book")
            case element(an:classification) return local:dispatch-element($node, $switch-map, "classifications")
            case element(gw:gawatiMeta) return local:dispatch-element($node, $switch-map, "gawatiMeta")
            default return local:default($node, $switch-map)
};


declare function local:dispatch-dateTime-handler($node, $switch-map) {
    if ($node/@refersTo eq "#docModifiedDate") then
        <gw:dateTime refersTo="#docModifiedDate" datetime="{current-dateTime()}" />
    else
        local:default($node, $switch-map)
};

declare function local:dispatch-element($node as node()*, $switch-map as map(*), $check-for as xs:string) {
    if (map:contains($switch-map, $check-for)) then
        map:get($switch-map, $check-for)
    else
        local:default($node, $switch-map)
};

declare function local:default($node as node()*, $switch-map) as item()* {
    element {name($node)} {($node/@*, docrewrite:rewriter($node/node(), $switch-map))}
};






