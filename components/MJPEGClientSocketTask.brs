'SocketClient MJPEG

sub init()
    print("Init SocketClient")
    m.top.functionName="runTask"
    m.top.control = "RUN"
end sub



function checkParameters(args as dynamic)
    if (invalid <> args.mediaType) and (invalid <> args.contentId) and (LCase(args.mediaType) = "mjpeg") then
        return true
    end if
    return false
end function


function setTestingParams() as Object
    args={}
    args["mediaType"] = "mjpeg"
	'Replace with the IP of your motioneye server
    args["contentId"] = "http://192.168.0.20:8081/"
    args["launchAppId"] = "837"
    args["appName"] = "Youtube"
    args["timeout"] = "30"
    return args
end function

function on_new_JPEG()
    print("ON JPEG FUnction")
end function

function runTask() as void
    m.port = CreateObject("roMessagePort")
    args = setTestingParams()
    print("Running SocketClient")
    if checkParameters(args)
         m.client = MJPEGClientSocket()
         m.client.url=args["contentId"]
         m.client.setMessagePort(m.port)
         m.client.connect()


    end if

    while(true)
        msg = wait(0, m.port)
        msgType = type(msg)
        if type(msg) = "roSGNodeEvent"
            if msg.getField() = "open"
            end if
        else if type(msg) = "roAssociativeArray"
            if msg.id = "on_open"
                m.top.on_open = msg.data
            else if msg.id = "on_close"
                m.top.on_close = msg.data
            else if msg.id = "on_new_jpeg"
                m.top.on_new_jpeg = msg.data
            end if
        end if

        m.client.run()
    end while
end function