xquery version "3.1";

import module namespace client-post="http://gawati.org/xq/client-db/services/post" at "../services/services-post.xql";

client-post:get-filtered-documents('{"docTypes": "all","itemsFrom": 1,"pageSize": 5, "roles":["client.Admin", "client.Public", "uma_authorization"], "title":"ss", "docType": ["",""], "fromDate": "1900-01-01", "toDate": "2100-12-12", "status": ["",""]}')