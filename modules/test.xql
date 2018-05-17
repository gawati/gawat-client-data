xquery version "3.1";

import module namespace client-post="http://gawati.org/xq/client-db/services/post" at "../services/services-post.xql";

client-post:get-filtered-documents('{"docTypes": "all","itemsFrom": 1,"pageSize": 5, "roles":["client.Submitter", "client.Public", "una_authorization"], "title":"", "docType": "", "fromDate": "1920-01-01", "toDate": "2018-12-12", "status": ""}')