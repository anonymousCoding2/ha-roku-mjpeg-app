' MJPEGClientSocket implementation

function MJPEGClientSocket() as object
    mcs={}

    mcs.OPCODES = {
        OP_BINARY:0
        OP_STRING:1
    }

    mcs.NET_STATES = {
        NONE: 0
        CONNECTING: 1
        OPEN: 2,
        CLOSING: 3,
        CLOSE: 4
    }

    mcs.HTTP_STATES = {
        NONE: 0,
        SEND_GET_REQUEST: 1,
        GET_RESPONSE_HEADER_START: 2,
        GET_RESPONSE_HEADER_END: 3,
        BOUNDARY_HEADER_START: 4,
        BOUNDARY_HEADER_END: 5
    }

    
    mcs.SEGMENT_SIZE=1024
    mcs.FRAME_SIZE=1024
    mcs.HTTP_HEADER_START_STR = "HTTP/1.1 200 OK"
    mcs.HTTP_HEADER_END_STR=chr(&H0D)+chr(&H0A)+chr(&H0D)+chr(&H0A)
    mcs.JPEG_FILE_BASE="MJPEGtemp"
    mcs.JPEG_FILE_EXT="jpeg"
    mcs.RECEIVE_BUFF_SIZE=1024
    'Test filesystem cachefs:
    mcs.JPEG_PATH="cachefs:"
    mcs.JPEG_BASE_NAME="mjpegcur"
    mcs.JPEG_MAX_NUM_FILES=3
    mcs.url=invalid
    mcs._socket=invalid
    mcs._readyState=mcs.NET_STATES.NONE
    mcs._http_state=mcs.HTTP_STATES.NONE
    mcs._sendAddress = invalid
    mcs._mcs_port=invalid
    mcs.failState=false
    mcs.headerResponse=CreateObject("roString")
    mcs.JPEGNum=0
    mcs.JPEGFileName=CreateObject("roString")
    mcs.receiveBuffer=invalid
    mcs.firstBoundary=false
    mcs.boundaryStr=CreateObject("roString")
    mcs.boundaryLen=0
    mcs.firstProcess=false


    mcs.connect = function()
        if m.url = invalid
            m.failState=true
            print("Error invalid url")
            return invalid
        end if

        if (m._mcs_port = invalid) or (type(m._mcs_port) <> "roMessagePort")
            m.failState=true
            print("Error invalid messagePort")
            return invalid
        end if

        urlObj = m._parseURL(m.url)

        if (urlObj = invalid) or (urlObj["address"] = invalid) or (urlObj["address"].Len() = 0)
            m.failState=true
            print("Error invalid urlobj")
            return invalid
        end if

        if (invalid = urlObj["path"]) or (urlObj["path"].Len() = 0)
            urlObj["path"]="/"
        end if

        m.networkStarted = true
        m._sendAddress = CreateObject("roSocketAddress")
        m._sendAddress.SetAddress(urlObj.address)
        if invalid <> urlObj.port
            m._sendAddress.SetPort(urlObj.port.ToInt())
        else
            m.failState=true
            print("Address Port set Failed "+str(urlObj.port))
            return invalid
        end if

        if not m._sendAddress.isAddressValid()
            print("sendAddress is not valid")
        end if
        m._socket = CreateObject("roStreamSocket")
        
        m._socket.setMessagePort(m._mcs_port)
        m._socket.notifyReadable(true)
        m._socket.notifyWritable(true)
        m._socket.notifyException(true)
        m._socket.setSendToAddress(m._sendAddress)
        m._socket.SetKeepAlive(true)

        m._socket.setMaxSeg(576)
        'm.SEGMENT_SIZE=m._socket.GetMaxSeg()
        m.SEGMENT_SIZE=576
        m.FRAME_SIZE=m.SEGMENT_SIZE

        If m._socket.Connect()
            Print "Connected Successfully"
            m._readyState = m.NET_STATES.CONNECTING

        else
            print "Error Failed to Connect"
        End If
    end function

    mcs.array_find_str = function(arrayObj, findStr, startPos=0 as Integer) as Integer
        if startPos >= arrayObj.Count()
            return -1
        end if
        findStrIdx = 0
        for i=startPos to arrayObj.Count()-1
            if arrayObj[i] = Asc(findStr.Mid(findStrIdx, 1))
                findStrIdx+=1
                if findStrIdx >= findStr.Len()
                    return i-(findStrIdx-1)
                end if
            else  if findStrIdx > 0
                i=i-findStrIdx
                findStrIdx=0
            end if
        end for
        return -1
    end function

    mcs.array_find_end_str = function(arrayObj, findStr, startPos=0 as Integer) as Integer
        if startPos >= arrayObj.Count()
            return -1
        end if
        findStrIdx = 0
        strLen=findStr.Len()-1
        aryLen=arrayObj.Count()-1
        for i=startPos to arrayObj.Count()-1
            rI=aryLen-i
            if arrayObj[rI] = Asc(findStr.Mid(strLen-findStrIdx, 1))
                findStrIdx+=1
                if findStrIdx >= findStr.Len()
                    return rI
                end if
            else if findStrIdx > 0
                i=i-findStrIdx
                findStrIdx=0
            end if
        end for
        return -1
    end function

    mcs.array_mid = function(origArray as object, startPos as Integer, desiredLen=0 as Integer) as dynamic
        if desiredLen <= 0 or (desiredLen > (origArray.Count()-startPos))
            desiredLen=origArray.Count()-startPos
        end if

        if desiredLen > (origArray.Count()-startPos)
            return invalid
        end if

        if startPos > origArray.Count()
            print("Error array_mid startPos is larger than size of array")
            return invalid
        end if

        newArray = CreateObject("roByteArray")

        for index=startPos to (startPos+desiredLen)-1
            newArray.push(origArray[index])
        end for

        return newArray
    end function

    mcs.byteToHex = function(IntVal as Integer) as String
        remainder = intVal Mod 16
        divisible = intVal-remainder
        resultStr = ""
        hexArray=["A","B","C","D","E","F"]

        divisible = Int(divisible/16)

        if divisible < 10
            resultStr+=Str(divisible).Trim()
        else
            tempVal = divisible-10
            resultStr+=hexArray[tempVal]
        end if

        if remainder < 10
            resultStr+=Str(remainder).Trim()
        else
            tempVal = remainder-10
            resultStr+=hexArray[tempVal]
        end if

        return resultStr
    end function

    mcs.byteArrayToHex = function(targetArray, startPos as Integer, desiredLen=0 as Integer) as String

        if desiredLen <= 0 or (desiredLen > (targetArray.Count()-startPos))
            desiredLen=targetArray.Count()-startPos
        end if

        if desiredLen > (targetArray.Count()-startPos)
            return invalid
        end if

        if startPos > targetArray.Count()
            print("Error array_mid startPos is larger than size of array")
            return invalid
        end if

        resultStr = ""
        endPos = (startPos+desiredLen)-1

        for index=startPos to endPos
            resultStr+="0x"+m.byteToHex(targetArray[index])
            if index <> endPos
                resultStr+=", "
            end if
        end for

        return resultStr
    end function

    mcs.incrementFile = function()
        m.JPEGNum+=1
        m.JPEGFileName=m.genFileName()
    end function

    mcs.genFileName = function(num=m.JPEGNum) as string
        curFileNum = m.JPEGNum MOD m.JPEG_MAX_NUM_FILES
        fileName=m.JPEG_PATH + "/" + m.JPEG_BASE_NAME + str(curFileNum).Trim()+"."+m.JPEG_FILE_EXT
        return fileName
    end function

    mcs.genHTTPGetHeader =function(urlObj as dynamic) as string

        http_get_header = "GET " + urlObj.path + " HTTP/1.1"+chr(&H0D)+chr(&H0A)
        http_get_header += "Host: "+ urlObj.address+chr(&H0D)+chr(&H0A)
        http_get_header += chr(&H0D)+chr(&H0A)
        return http_get_header
    
    end function

    mcs._parseURL = function(lURL) as object
        urlObj = {}
        r = CreateObject("roRegex", "(https?)\://([^/:]+)(?::(\d+))?(.*)?","")
        result = r.Match(lURL)

        'resultLen = arrayLen(result)
        resultLen = result.Count()

        urlObj["protocol"] = result?[1]
        urlObj["address"] = result?[2]
        urlObj["port"] = result?[3]
        urlObj["path"] = result?[4]

        if invalid <> urlObj["address"]
            colonPos = urlObj["address"].instr(":")

            if invalid = urlObj["port"]
                urlObj["port"]=80
            end if
        end if

        if invalid = urlObj["path"]
            urlObj["path"]="/"
        end if

        return urlObj
    end function

    'Convert HTTP Header string to dictionary of HTTP Params and values
    mcs._parseHTTPHeader = function(headerStr as String)
        httpDict={}
        'split by /r/n
        lines=headerStr.Split(chr(&H0D)+chr(&H0A))
        For index=0 to lines.Count()-1:
            line = lines[index]
            httpParamPos=Instr(0, line, ":")
            if httpParamPos > 0:
                dictKey = line.Mid(0,httpParamPos-1).Trim()
                dictValue = line.Mid(httpParamPos+1).Trim()
                httpDict[dictKey]= dictValue
            end if
        end for
        return httpDict
    end function

    'Pass in the httpDict as parse with _parseHTTPHeader
    mcs._getBoundaryParam = function(httpDict as object)
        result=CreateObject("roString")
        if invalid <> httpDict["Content-Type"]
            boundaryIndex = httpDict["Content-Type"].Instr("boundary=")
            if boundaryIndex > 0
                result=httpDict["Content-Type"].Mid(boundaryIndex+9).Trim()
            end if
        end if
        return result
    end function

    mcs.setMessagePort = function(messagePort as dynamic)
        m._mcs_port = messagePort
    end function

    mcs._post_message = function(msgId as String, msgData as dynamic)
        if m._mcs_port <> invalid
            m._mcs_port.postMessage({
                id: msgId,
                data: msgData
            })
        end if
    end function

    'Send message to HTTP server
    ' @param message roByte array
    mcs.send = function(message as object) as integer
        if (invalid = m._socket) or (m._readyState <> m.NET_STATES.OPEN)
            m.failState=true
            print("Error invalid socket state")
            return -1
        end if

        opcode=m.OPCODES.OP_BINARY

        if invalid = message
            m.failState=true
            print("Error invalid message")
            return -1
        end if

        bytes = createObject("roByteArray")
        msgLen = 0

        msgType=type(message)
        if "roByteArray" = msgType
            opcode = m.OPCODES.OP_BINARY
            msgLen = message.Count()
            for each byte in message
                bytes.push(byte)
            end for
        else if "roString" = msgType
            opcode = m.OPCODES.OP_STRING
            msgLen = Len(message)
            
            bytes.fromAsciiString(message)
        else
            m.failState=true
            print("Error message type is invalid")
            return -1
        end if

        

        maxFrames = msgLen/m.FRAME_SIZE
        if maxFrames < 1 then maxFrames = 1
        curBytesSent=0
        totalBytesSent=0
        startPos=0

        for curFrame=0 to maxFrames-1
            startPos=curFrame*m.FRAME_SIZE
            baSize = m.FRAME_SIZE
            if  maxFrames-1 = curFrame
                baSize =msgLen-((maxFrames-1)*m.FRAME_SIZE)
            end if
            curBytesSent=m._socket.Send(bytes, startPos, baSize)
            totalBytesSent+=curBytesSent


        end for

        return totalBytesSent
    end function

    mcs.receive = function() as dynamic
        if invalid = m._socket or m._readyState <> m.NET_STATES.OPEN
            m.failState=true
            print("Error invalid socket state")
            return invalid
        end if

        if not m._socket.IsReadable()
            m.failState=true
            print("Error Socket not readable send function")
            return invalid
        end if

        bytesReceived = createObject("roByteArray")
        buffer = createObject("roByteArray")
        buffer[1024]=0
        curBytesCount=0
        totalBytesCount=0
        receiveBufferCount=m._socket.GetCountRcvBuf()

        
        
        while m._socket.IsReadable() and (receiveBufferCount > 0)
            receiveSize=1024
            if receiveBufferCount < receiveSize
                receiveSize = receiveBufferCount
            end if

            'curBytes.Resize(receiveSize)
            curBytesCount=m._socket.Receive(buffer, 0, receiveSize)
            totalBytesCount+=curBytesCount
            if curBytesCount <> buffer.Count()
                bytesReceived.append(m.array_mid(buffer, 0, curBytesCount))
            else
                bytesReceived.append(buffer)
            end if
            
            'buffer.Clear()
            receiveBufferCount=m._socket.GetCountRcvBuf()
        end while

        return bytesReceived
    end function

    mcs.processHTTP = function(curBytes)
        
    end function

    'Process socket Events
    mcs.processEvents = function()

        if m._socket.IsException()
            print("ERROR Connection Exception")
            m._readyState=m.NET_STATES.CLOSE
            m._post_message("on_close", true)

            
            if m._socket.eConnAborted()
                print("ERROR Connection aborted")
            end if
            if m._socket.eConnRefused()
                print("ERROR Connection aborted")
            end if
            if m._socket.eConnReset()
                print("ERROR Connection aborted")
            end if
            if m._socket.eIsConn()
                print("ERROR Connection aborted")
            end if
            if m._socket.eNotConn()
                print("ERROR Connection aborted")
            end if
            
        end if

        if m._socket.IsWritable()
            if m._readyState = m.NET_STATES.CONNECTING
                m._readyState=m.NET_STATES.OPEN
                m._post_message("on_open", true)
                print("Socket Open")
            end if
            if m._http_state=m.HTTP_STATES.NONE
                print("Send data")
                urlObj = m._parseURL(m.url)
                headerStr = m.genHTTPGetHeader(urlObj)
                headerLen=headerStr.Len()
                actSentLen=m.send(headerStr)
                if actSentLen <> headerLen
                    print("send str len and actual send count are different")
                else
                    m._http_state=m.HTTP_STATES.GET_RESPONSE_HEADER_START
                    print("Start reading data")
                    m._readyState = m.NET_STATES.OPEN
                end if
            end if
        end if
            
        if (m._socket.IsReadable()) and (m._http_state <> m.HTTP_STATES.NONE)
            bytes=invalid
            if not m.firstProcess
                bytes=m.receive()
            end if
            m.firstProcess=false

            if m._http_state = m.HTTP_STATES.GET_RESPONSE_HEADER_START
                'curResponse=bytes.ToAsciiString()
                if invalid <> bytes
                    m.receiveBuffer.append(bytes)
                end if
                'print(curResponse)
                'm.headerResponse+=curResponse
                m.firstProcess=true
                
                'headerIndex = m.headerResponse.Instr(m.HTTP_HEADER_START_STR)
                headerIndex = m.array_find_end_str(m.receiveBuffer, m.HTTP_HEADER_START_STR)
                if headerIndex <> -1
                    print("Reader start header")
                    m.receiveBuffer=m.array_mid(m.receiveBuffer, headerIndex)
                    m.headerResponse=m.receiveBuffer.ToAsciiString()
                    m._http_state = m.HTTP_STATES.GET_RESPONSE_HEADER_END
                end if
            end if
            if m._http_state = m.HTTP_STATES.GET_RESPONSE_HEADER_END
                if not m.firstProcess
                    if invalid <> bytes
                        m.receiveBuffer.append(bytes)
                    end if
                    'curResponse=bytes.ToAsciiString()
                    'm.headerResponse+=curResponse
                end if
                headerIndex = m.array_find_end_str(m.receiveBuffer, m.HTTP_HEADER_START_STR)
                'headerIndex = m.headerResponse.Instr(m.HTTP_HEADER_END_STR)
                if headerIndex <> -1
                    m.receiveBuffer=m.array_mid(m.receiveBuffer, 0, headerIndex)
                    m.headerResponse=m.receiveBuffer.ToAsciiString()
                    m._http_state = m.HTTP_STATES.BOUNDARY_HEADER_START

                    bytes.Clear()
                    
                    httpDict = m._parseHTTPHeader(m.headerResponse)
                    m.boundarStr=m._getBoundaryParam(httpDict)

                    print(httpDict)
                    m.receiveBuffer=m.array_mid(m.receiveBuffer, 0, headerIndex)
                end if
            end if
            if m._http_state > m.HTTP_STATES.GET_RESPONSE_HEADER_END
                if invalid <> bytes
                    m.receiveBuffer.append(bytes)
                end if
                
                if m._http_state = m.HTTP_STATES.BOUNDARY_HEADER_START
                    'curResponse=m.receiveBuffer.ToAsciiString()
                    'print("curResponse "+curResponse)

                    initialHeader = m.array_find_str(m.receiveBuffer, "--")
                    if initialHeader <> -1
                        if initialHeader = (m.receiveBuffer.Count()-2)
                            'm.receiveBuffer=m.array_mid(m.receiveBuffer, initialHeader)
                        else
                            m.firstProcess=true
                            initialHeader = m.array_find_str(m.receiveBuffer, "--"+m.boundaryStr)
                            if -1 <> initialHeader
                                'Boundary start of header found
                                m._http_state = m.HTTP_STATES.BOUNDARY_HEADER_END
                                'curResponse = curResponse.Mid(initialHeader, curResponse.Len()-initialHeader)
                                if m.firstBoundary
                                    'Save JPEG
                                    
                                    endJPEGIndex = m.array_find_end_str(m.receiveBuffer, m.HTTP_HEADER_END_STR, m.receiveBuffer.Count()-initialHeader)

                                    'endJPEGIndex = initialHeader

                                    if endJPEGIndex <> -1

                                        tempStr = m.byteArrayToHex(m.receiveBuffer, 0, 2)


                                        'print("2 bytes beginning "+tempStr)

                                        tempStr = m.byteArrayToHex(m.receiveBuffer, endJPEGIndex-10, 10)


                                        'print("10 bytes before end "+tempStr)
                                    end if

                                    'm.genFileName
                                    m.receiveBuffer.WriteFile(m.JPEGFileName, 0, endJPEGIndex)
                                    m._post_message("on_new_jpeg", m.JPEGFileName)
                                    m.incrementFile()

                                    'print("New JPEG file expected: "+Str(m.boundaryLen)+" received size: "+Str(endJPEGIndex))
                                    
                                end if
                                    'Remove everything until the start of boundary header
                                    m.receiveBuffer = m.array_mid(m.receiveBuffer, initialHeader)
                                    'for i=0 to initialHeader
                                    '    m.receiveBuffer.Shift()
                                    'end for
                            end if
                        end if
                    end if
                end if
                if m._http_state = m.HTTP_STATES.BOUNDARY_HEADER_END
                    'curResponse=m.receiveBuffer.ToAsciiString()
                    headerIndex = m.array_find_str(m.receiveBuffer, m.HTTP_HEADER_END_STR)
                    if headerIndex <> -1
                        m.firstProcess=true
                        m._http_state = m.HTTP_STATES.BOUNDARY_HEADER_START
                        if not m.firstBoundary
                            m.firstBoundary=true
                        end if
                        
                        responseArray = m.array_mid(m.receiveBuffer, 0, headerIndex)
                        curResponse=responseArray.ToAsciiString()
                        headerEnd = headerIndex +m.HTTP_HEADER_END_STR.Len()

                        httpDict = m._parseHTTPHeader(curResponse)

                        'print("boundary httpDict ")
                        'print(httpDict)

                        if invalid <> httpDict["Content-Length"]
                            m.boundaryLen=httpDict["Content-Length"].Trim().ToInt()
                            if invalid <> httpDict["Content-type"]
                                typeStr = httpDict["Content-type"]
                                typeStr=LCase(typeStr)
                                position = InStr(0, typeStr, "jpeg") 
                                if 0 = position
                                    print("ERROR MJPEG stream is not JPEG")
                                    m._try_close()
                                end if
                            end if
                        end if

                        'Remove everything until the start of boundary header
                        'm.receiveBuffer=m.array_mid(m.receiveBuffer, headerEnd)
                        for i=0 to headerEnd-1
                            m.receiveBuffer.Shift()
                        end for
                    end if
                        
                end if
            end if
        end if

        
    end function

    mcs.run = function() as object
        msg = wait(200, m._mcs_port)
        msgType = type(msg)
        if msgType = "roSocketEvent" then
            m.processEvents()
        end if
    end function

    mcs.close = function()
        m._readyState=m.NET_STATES.CLOSING
        m._socket.Close()
    end function

    mcs._try_close = function()
        m._readyState=m.NET_STATES.CLOSING

        m._socket.close()
        m.on_close=true
        m._readyState=m.NET_STATES.CLOSE
    end function

    mcs.genFileName()
    mcs.receiveBuffer = CreateObject("roByteArray")

    return mcs
end function