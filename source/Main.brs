'MJPEG clientSocket


sub Main()
    print "in showChannelSGScreen"
    'Indicate this is a Roku SceneGraph application'
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)

    'Create a scene and load /components/main.xml'
    scene = screen.CreateScene("Main")
    screen.show()

    while(true)
        msg = wait(0, m.port)
        msgType = type(msg)
        if msgType = "roSGScreenEvent"
            if msg.isScreenClosed()
                'Send Network close
                return
            end if
        end if
    end while
end sub

function on_new_jpeg(eventData)
    fieldname = eventData.getField()
    data = eventData.getData()
    if not m.firstJPEG
        'm.pictureViewer.uri=data
        m.firstJPEG=true
    end if
    m.pictureViewer.uri=data
    print("On New JPEG name: "+data)
end function

function close_button_fire()
    m.mcs.close=true
end function

function init()
    m.top.setFocus(true)
    m.myLabel = m.top.findNode("myLabel")
    m.pictureViewer = m.top.findNode("MJPEGViewer")
    m.netBtn = m.top.findNode("closeNetBtn")
    m.firstJPEG=false

    m.netBtn.observeField("fire", "close_button_fire")
    
    'Set the font size
    m.myLabel.font.size=92

    'Set the color to light blue
    m.myLabel.color="0x72D7EEFF"

    m.mcs  = createObject("roSGNode", "MJPEGClientSocket")
    m.mcs.observeField("on_new_jpeg", "on_new_jpeg")
    m.netBtn.SetFocus(true)
end function