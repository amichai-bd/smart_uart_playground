import socket
import sys

#-------------------------------------------------------------------- 

class port : 

    def __init__(self):
    
      self.port_name = "tcp://localhost:1234"
      self.sock = None
      self.connection = None
      self.connect()

    #--------------------------------------------------------------------    
    
    def connect(self) :
    
        # Create a TCP/IP socket
      self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
      self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1) # attempt to prevent: socket.error: [Errno 98] Address already in use
      
      # Bind the socket to the port
      server_address = ('localhost', 1234)
      print ('PY: starting up on %s port %s' % server_address)
      self.sock.bind(server_address)
      
      # Listen for incoming connections
      self.sock.listen(1)
      
      # Wait for a connection
      print ('PY: waiting for a connection')
      self.connection, client_address = self.sock.accept()
      
      print ('PY connection from', client_address)
      
      data = self.connection.recv(1024)
      print ( 'PY: received "%s"' % data)
      if data:
          print('PY: sending data back to the client')
          msg = "PY: Hello from Python, got your message: ".encode()  + data
          self.connection.sendall(msg)

      else:
          print ( 'PY: no data from', client_address)
      
        
    #-------------------------------------------------------------------- 

    def disconnect(self) :
         self.connection.close()

    #------------------------------------------------------------

    def write_reg(self,addr,data) :        
       self.connection.sendall(("W %x %x\n"%(addr,data)).encode())       
      
    #-------------------------------------------------------------------- 
  
    def read_reg_unsigned(self,addr) :
        
       self.connection.sendall(("R %x\n"%addr).encode())    
       data = self.connection.recv(1024)  # get response       
       return int(data,16)
       

    #------------------------------------------------------------

    def read_reg(self,addr) :  # returns signed value , for unsigned call directly read_reg_unsigned
     
       data = self.read_reg_unsigned(addr)
       
       if (data >= 2**31) :   # convert to signed 32 bit integer value         
          data = -int(((~data)+1) & 0xffffffff)
       
       return data
                       
    #------------------------------------------------------------
    
    def quit(self) :
       self.connection.sendall("Q\n".encode())           
       self.disconnect() 
       quit()       
      
    #------------------------------------------------------------

