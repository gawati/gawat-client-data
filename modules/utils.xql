module namespace utils="http://gawati.org/1.0/client/utils";


declare function utils:is-date($date) {
    try{
        let $d := xs:date($date)    
        return true()
    } catch * {
         false()
    }

};


declare function utils:iri-upto-date-part($iri as xs:string) {
    let $arr := tokenize($iri, "/")[position() ne 1]
    let $which-is-date :=
        for $a at $pos in $arr
            return utils:is-date($a)
    return
        "/" ||
        string-join(
            $arr[
                position() le 
                    index-of($which-is-date, true())
            ],
            "/"
        )
};
