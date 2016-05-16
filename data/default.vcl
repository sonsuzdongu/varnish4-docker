vcl 4.0;

import std;

backend default {
    .host = "test.sonsuzdongu.com"; 
    .port = "80";
    .max_connections = 3000;
    .probe = { 
        .url = "/"; 
        .interval  = 50s; # check the health of each backend every 50 seconds
        .timeout   = 10s;
        # 3/5 of backend responses are succeeded, than we consider its healthy
        .window    = 5; 
        .threshold = 3;
    }
    .first_byte_timeout     = 300s;
    .connect_timeout        = 5s;
    .between_bytes_timeout  = 2s;
}

# access control list for allowed ip addresses to PURGE
acl purge {
   "localhost";
   "127.0.0.1";
   "172.17.0.1"; # docker
}

sub vcl_recv {
    if (req.http.Varnish-Forwarded-For) {
        set req.http.Varnish-Forwarded-For = req.http.Varnish-Forwarded-For + ", " + client.ip;
    } else {
        set req.http.Varnish-Forwarded-For = client.ip;
    }

    # sort query params
    set req.url = std.querysort(req.url);

    # Strip hash and trailing ?
    set req.url = regsub(req.url, "\#.*$", "");
    set req.url = regsub(req.url, "\?$", "");

    #remove some marketing / google parameters from url
    if (req.url ~ "(\?|&)(utm_source|utm_medium|utm_campaign|utm_content|gclid|cx|ie|cof|siteurl)=") {
        set req.url = regsuball(req.url, "&(utm_source|utm_medium|utm_campaign|utm_content|gclid|cx|ie|cof|siteurl)=([A-z0-9_\-\.%25]+)", "");
        set req.url = regsuball(req.url, "\?(utm_source|utm_medium|utm_campaign|utm_content|gclid|cx|ie|cof|siteurl)=([A-z0-9_\-\.%25]+)", "?");
        set req.url = regsub(req.url, "\?&", "?");
        set req.url = regsub(req.url, "\?$", "");
    }

    # Normalize headers
    if (req.http.Accept-Encoding) {
        if (req.http.Accept-Encoding ~ "gzip") {
            set req.http.Accept-Encoding = "gzip";
        } elsif (req.http.Accept-Encoding ~ "deflate") {
            set req.http.Accept-Encoding = "deflate";
        } else {
            unset req.http.Accept-Encoding;
        }
    }

    # Allow purging
    # curl -X PURGE http://localhost:6081/url-to-purge
    if (req.method == "PURGE") {
        if (!client.ip ~ purge) {
            return (synth(405, "Access denied for purging"));
        }
        ban("req.url ~ "+req.url);
        return(synth(200, "Purged"));
    }

    # Only cache GET and HEAD requests
    if (req.method != "GET" && req.method != "HEAD") {
        return (pass);
    }

    # blacklist
    if (req.url ~ "wp-admin" ||
        req.url ~ "admin" ||
        req.url ~ "my-account" ||
        req.http.Cookie ~ "logged-in")  
    {
        return (pass);
    }

    # Remove cookies
    unset req.http.Cookie;

    set req.http.Varnish-Grace = "NO";

    return (hash);
}

sub vcl_hash {
    hash_data(req.url);
}

sub vcl_hit {
    if (obj.ttl >= 0s) {
        # deliver if exists on ttl
        return (deliver);
    }
    
    if (obj.ttl + obj.grace > 0s) {
        set req.http.Varnish-Grace = "YES";
        return (deliver);
    } else {
        # no grace object
        return (fetch);
    }

    return (fetch);
}

sub vcl_backend_response {
    # handle redirects
    if (beresp.status == 301 || beresp.status == 302) {
        set beresp.http.Location = regsub(beresp.http.Location, ":[0-9]+", "");
    }


    # blacklist
    if (bereq.url !~ "wp-admin" ||
        bereq.url !~ "admin" ||
        bereq.url !~ "my-account" ||
        bereq.http.Cookie !~ "logged-in")  
    {
        unset beresp.http.set-cookie;
        set beresp.http.Varnish-Cacheable = "YES";
    } else {
        set beresp.http.Varnish-Cacheable = "NO";
    }

    set beresp.ttl = 10s; # go to backend on every 10th second of invalid cached request

    # Grace period on incoming objects
    set beresp.grace = 10h;

    return(deliver);
}


sub vcl_deliver {

    if (obj.hits > 0) {
        set resp.http.Varnish-Cache = "HIT";
        set resp.http.Varnish-Cache-Hits = obj.hits;
    } else {
        set resp.http.Varnish-Cache = "MISS";
    }

    set resp.http.Varnish-Grace = req.http.Varnish-Grace;

    return (deliver);
}
