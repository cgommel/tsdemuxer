http_mime={}
http_err={}
http_vars={}

-- http_mime types
http_mime['html']='text/html'
http_mime['htm']='text/html'
http_mime['xml']='text/xml'
http_mime['txt']='text/plain'
http_mime['cpp']='text/plain'
http_mime['h']='text/plain'
http_mime['lua']='text/plain'
http_mime['jpg']='image/jpeg'
http_mime['png']='image/png'
http_mime['ico']='image/vnd.microsoft.icon'
http_mime['mpeg']='video/mpeg'

-- http http_error list
http_err[100]='Continue'
http_err[101]='Switching Protocols'
http_err[200]='OK'
http_err[201]='Created'
http_err[202]='Accepted'
http_err[203]='Non-Authoritative Information'
http_err[204]='No Content'
http_err[205]='Reset Content'
http_err[206]='Partial Content'
http_err[300]='Multiple Choices'
http_err[301]='Moved Permanently'
http_err[302]='Moved Temporarily'
http_err[303]='See Other'
http_err[304]='Not Modified'
http_err[305]='Use Proxy'
http_err[400]='Bad Request'
http_err[401]='Unauthorized'
http_err[402]='Payment Required'
http_err[403]='Forbidden'
http_err[404]='Not Found'
http_err[405]='Method Not Allowed'
http_err[406]='Not Acceptable'
http_err[407]='Proxy Authentication Required'
http_err[408]='Request Time-Out'
http_err[409]='Conflict'
http_err[410]='Gone'
http_err[411]='Length Required'
http_err[412]='Precondition Failed'
http_err[413]='Request Entity Too Large'
http_err[414]='Request-URL Too Large'
http_err[415]='Unsupported Media Type'
http_err[500]='Internal Server http_error'
http_err[501]='Not Implemented'
http_err[502]='Bad Gateway'
http_err[503]='Out of Resources'
http_err[504]='Gateway Time-Out'
http_err[505]='HTTP Version not supported'

http_vars['fname']='UPnP-IPTV'
http_vars['manufacturer']='Anton Burdinuk'
http_vars['manufacturer_url']='clark15b@gmail.com'
http_vars['description']=ssdp_server
http_vars['name']='xupnpd'
http_vars['version']='0.0.1'
http_vars['url']=''
http_vars['uuid']=ssdp_uuid
http_vars['interface']=ssdp.interface()
http_vars['port']=cfg.http_port

http_templ=
{
    '/dev.xml',
    '/wmc.xml',
    '/index.html'
}

dofile('xupnpd_soap.lua')

function http_send_headers(err,ext,len)
    http.send(
        string.format(
            "HTTP/1.0 %i %s\r\nServer: %s\r\nDate: %s\r\nContent-Type: %s\r\nConnection: close\r\n",
            err,http_err[err] or 'Unknown',ssdp_server,os.date('!%a, %d %b %Y %H:%M:%S GMT'),http_mime[ext] or 'application/x-octet-stream')
    )
    if len then http.send(string.format("Content-Length: %i\r\n",len)) end
    http.send("\r\n",len)
end

function get_soap_method(s)
    local i=string.find(s,'#',1)
    if not i then return s end
    return string.sub(s,i+1)
end


function http_handler(what,from,port,msg)

    if not msg or not msg.reqline then return end

    if msg.reqline[2]=='/' then msg.reqline[2]='/index.html' end

    local head=false

    local f=util.geturlinfo(cfg.www_root,msg.reqline[2])

    if not f or (msg.reqline[3]~='HTTP/1.0' and msg.reqline[3]~='HTTP/1.1') then
        http_send_headers(400)
        return
    end

    if cfg.debug>0 then print(from..' '..msg.reqline[1]..' '..msg.reqline[2]) end

    if msg.reqline[1]=='HEAD' then head=true msg.reqline[1]='GET' end

    if msg.reqline[1]=='POST' then
        if f.url=='/soap' then

            if cfg.debug>0 then print(from..' SOAP '..msg.soapaction or '') end

            local s=services[ f.args['s'] ]

            if not s then http_send_headers(404) return end     -- interface is not found

            local func_name=get_soap_method(msg.soapaction)
            local func=s[func_name]

            if not func then http_send_headers(404) return end  -- method is not found

            if cfg.debug>1 then print(msg.data) end

            local r=soap.find('Envelope/Body/'..func_name,soap.parse(msg.data))

            if not r then http_send_headers(400) return end

            http_send_headers(200,'xml')

            r=func(r)

            if not r then
                http.send(
                '<?xml version=\"1.0\" encoding=\"utf-8\"?>'..
                '<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">'..
                   '<s:Body>'..
                      '<s:Fault>'..
                         '<faultcode>s:Client</faultcode>'..
                         '<faultstring>UPnPError</faultstring>'..
                         '<detail>'..
                            '<u:UPnPError xmlns:u=\"urn:schemas-upnp-org:control-1-0\">'..
                               '<u:errorCode>501</u:errorCode>'..
                               '<u:errorDescription>Action Failed</u:errorDescription>'..
                            '</u:UPnPError>'..
                         '</detail>'..
                      '</s:Fault>'..
                   '</s:Body>'..
                '</s:Envelope>'
                )
            else
                http.send(
                    string.format(
                        '<?xml version=\"1.0\" encoding=\"utf-8\"?>'..
                        '<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">'..
                        '<s:Body><u:%sResponse xmlns:u=\"%s\">%s</u:%sResponse></s:Body></s:Envelope>',                                                            
                            func_name,s.schema,soap.serialize(r),func_name)
                        )
            end
        else
            http_send_headers(404)
        end
    elseif msg.reqline[1]=='SUBSCRIBE' then
        http.send(
            string.format(
                "HTTP/1.0 200 OK\r\nServer: %s\r\nDate: %s\r\nConnection: close\r\nSID: uuid:%s\r\nTIMEOUT: Second-1800\r\n\r\n",ssdp_server,
                os.date('!%a, %d %b %Y %H:%M:%S GMT'),core.uuid()))

    elseif msg.reqline[1]=='UNSUBSCRIBE' then
        http.send(
            string.format(
                "HTTP/1.0 200 OK\r\nServer: %s\r\nDate: %s\r\nConnection: close\r\nEXT:\r\n\r\n",ssdp_server,os.date('!%a, %d %b %Y %H:%M:%S GMT')))

    elseif msg.reqline[1]=='GET' then
        if f.url=='/proxy' then

            local pls=find_playlist_object(f.args['s'] or '')

            if not pls then http_send_headers(404) return end

            http.send(string.format(
                "HTTP/1.0 200 OK\r\nServer: %s\r\nDate: %s\r\nPragma: no-cache\r\nCache-control: no-cache\r\nContent-Type: %s\r\nConnection: close\r\n"..
                "TransferMode.DLNA.ORG: Streaming\r\nAccept-Ranges: none\r\nEXT:\r\n",ssdp_server,os.date('!%a, %d %b %Y %H:%M:%S GMT'),pls.mime[3]))

            if pls.dlna_extras~='*' then
                http.send('ContentFeatures.DLNA.ORG: '..pls.dlna_extras..'\r\n')
            end

            http.send('\r\n')
            http.flush()

            if head~=true then
                if cfg.debug>0 then print(from..' PROXY '..pls.url..' <'..pls.mime[3]..'>') end
                http.sendurl(pls.url)
            end

        elseif f.url=='/reload' then
            http_send_headers(200,'txt')

            if head~=true then
                http.send('OK')
                core.sendevent('reload')
            end
        else
            if f.type=='none' then http_send_headers(404) return end
            if f.type~='file' then http_send_headers(403) return end

            local tmpl=false

            for i,fname in ipairs(http_templ) do
                if f.url==fname then tmpl=true break end
            end

            local len=nil

            if not tmpl then len=f.length end

--            if f.url=='/reload.mpeg' then core.sendevent('reload') end

            http_send_headers(200,f.ext,len)

            if head~=true then
                if cfg.debug>0 then print(from..' FILE '..f.path) end
                if tmpl then http.sendtfile(f.path,http_vars) else  http.sendfile(f.path) end
            end
        end
    else
        http_send_headers(405)
    end

    http.flush()
end

events["http"]=http_handler

http.listen(cfg.http_port,"http")