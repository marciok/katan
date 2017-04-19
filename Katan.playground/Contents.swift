//
//  main.swift
//  KatanSandbox
//
//  Created by Marcio Klepacz on 3/27/17.
//  Copyright © 2017 Marcio Klepacz. All rights reserved.
//

import Foundation
/*:
 # Katan
 A micro web server that replies *"Hello world!"* to every request
 
 The idea is to show the basics steps to create a web server in Swift.
 
 *A web server overview:*
 
 ![alt text](cloud+flow_final.png)
 
 
 ## 1. Create Socket 🐣
 */

func startWebServer(){
    
    let socketDescriptor = Darwin.socket(AF_INET, SOCK_STREAM, 0)
    
/*:
 `socket` -- creates an endpoint for communication and returns a descriptor.
 
 **domain**: Communication domain, selects the protocol family, in our case ipv4 (AF_INET). AF_INET6 if we wanted to use ipv6.
 
 **type**: Specifies semantics of communication. A SOCK_STREAM type provides sequenced, reliable, two-way connection based byte streams.
 
 **protocol**: The protocol specifies a particular protocol to be used with the socket.
 Normally only a single protocol exists to support a particular socket type within a given protocol family
 
 Returns -1 if there's an error otherwise the descriptor (a reference).
 */

/*:
 ## 2. Set options 🎛
 */
    
    var noSigPipe: Int32 = 1
    setsockopt(socketDescriptor, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
/*:
 `setsockopt` -- get and set options on sockets
 
 **socket**: The socket descriptor
 
 **level**: To manipulate options at the socket level
     
 **option_name**: The name of our the option, in our case we do not generate SIGPIPE, instead return EPIPE
 A SIGPIPE is sent to a process if it tried to write to a socket that had been shutdown for writing or isn't connected (anymore).
 
 **socklen_t**: the option length
 
 ## 3. Create adress and bind 🚪➕🔌
 
 ![alt text](overview.png)
 */
    let port: in_port_t = 9292
    
    var address = sockaddr_in(
        sin_len: UInt8(MemoryLayout<sockaddr_in>.stride),
        sin_family: UInt8(AF_INET),
        sin_port: port.bigEndian,
        sin_addr: in_addr(s_addr: in_addr_t(0)),
        sin_zero:(0, 0, 0, 0, 0, 0, 0, 0) // Add some padding, more info at: http://stackoverflow.com/questions/15608707/why-is-zero-padding-needed-in-sockaddr-in#15609050
    )
    
    var bindResult: Int32 = -1
    bindResult = withUnsafePointer(to: &address) {
        bind(socketDescriptor, UnsafePointer<sockaddr>(OpaquePointer($0)), socklen_t(MemoryLayout<sockaddr_in>.size))
    }
/*:
 
`bind` -- assigns a name to an unnamed socket.
 
  When a socket is created with socket() it exists in a name space (address family) but has no name
 assigned. bind() requests that address be assigned to the socket.
 
 */
    
    if bindResult == -1 {
        fatalError(String(cString: UnsafePointer(strerror(errno))))
    }
    
/*:
 ## 4. Listen 📡
 */
    listen(socketDescriptor, SOMAXCONN)
/*:
 `listen` -- for connections on a socket
 
 The backlog parameter defines the maximum length for the queue of pending
 connections.  If a connection request arrives with the queue full, the
 client may receive an error with an indication of ECONNREFUSED.
 
 */

/*:
 ## 5.  Accept connection on socket ✅
*/
    
    print("Starting HTTP server on port \(port)")
    repeat {
        var address = sockaddr()
        var length: socklen_t = 0
        
        let clientSocket = accept(socketDescriptor, &address, &length)
        if clientSocket == -1 {
            fatalError(String(cString: UnsafePointer(strerror(errno))))
        }
/*:
`accept` -- extracts the first connection request on the queue of pending connections,
         
 Creates a new socket with the same properties of
 socket, and allocates a new file descriptor for the socket.
 
 The argument address is a result parameter that is filled in with the
 address of the connecting entity, as known to the communications layer.
 
 The address_len is a value-result
 parameter; it should initially contain the amount of space pointed to by
 address; on return it will contain the actual length (in bytes) of the
 address returned.
 */

        var characters = ""
        var received: UInt8 = 0
        repeat {
            var buffer = [UInt8](repeatElement(0, count: 1))
            
            
/*:
## 6. Read socket 📖

`recv` -- receive a message from a socket

*/
            let resp = recv(clientSocket, &buffer, Int(buffer.count), 0)
            if resp <= 0 {
                fatalError(String(cString: UnsafePointer(strerror(errno))))
            }
            
            received = buffer.first!
            if received > 13 /* Carriage Return on ASCII table */ {
                characters.append(Character(UnicodeScalar(received)))
            }
        } while received != 10 /* New Line on ASCII table */
        
        print("Received -> \(characters)")
/*:
## 7. Write response 📝

`write` -- write output

*/
        let message = "HTTP/1.1 200 OK\r\n\r\n Hello World!"
        print("Response -> \(message)")
        let messageData = ArraySlice(message.utf8)
        
        _ = messageData.withUnsafeBytes {

            write(clientSocket, $0.baseAddress, messageData.count)
        }
        
/*:
## 8. Close socket ⚰️

`close` -- delete a descriptor

*/
        close(clientSocket)
        
    } while true
    
}

