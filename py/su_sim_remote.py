import socket
import sys

#-------------------------------------------------------------------- 

class su_sim_remote: 

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
      
    #-------------------------------------------------------------------- 
  
    def read(self,addr) :
        
       self.connection.sendall(("R %x\n"%addr).encode())    
       data = self.connection.recv(1024)  # get response       
       return int(data,16)
       

    #------------------------------------------------------------
    
    def write(self,addr,data) :        
       self.connection.sendall(("W %x %x\n"%(addr,data)).encode())       
       

    #------------------------------------------------------------

    def config_wp_uart(self,uart_ref_clk_mhz,uart_baudrate) : 
       clk_div_cntr = int((float(1000000)*float(uart_ref_clk_mhz))/float(uart_baudrate))-1
       print("PY: Changing clk_div_cntr to %d (decimal)" % clk_div_cntr)    
       self.write(12,(1<<16)+clk_div_cntr)   # configure WP  valid + value    
       self.connection.sendall(("U %x\n" % clk_div_cntr).encode())  # configure Testbench    

    #------------------------------------------------------------

    
    def quit(self) :
       self.connection.sendall("Q\n".encode())           
       self.disconnect() 
       quit()       
      
    #------------------------------------------------------------

