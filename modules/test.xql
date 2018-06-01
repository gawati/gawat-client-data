xquery version "3.1";

import module namespace client-post="http://gawati.org/xq/client-db/services/post" at "../services/services-post.xql";
import module namespace store="http://gawati.org/1.0/client/store" at "../modules/store.xqm";

import module namespace config="http://gawati.org/client-data/config";

store:delete-doc("/akn/mu/act/legge/1919-10-24/GN_212-1919/eng@/!main")
