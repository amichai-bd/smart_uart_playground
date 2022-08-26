
import serial
import get_usb_serial_port

class port :

          def __init__(self):
          
             self.port_name      = get_usb_serial_port.get_usb_serial_port()
             if (self.port_name==None) :
                print("No Active USB Serial Port, quitting")
                exit()          
         
             self.SU_CMD_WR_WORD = 0x80   
             self.SU_CMD_RD_WORD = 0x83  
             self.SU_CMD_RSP     = 0x88          
             self.ser_port       = None

             
             self.configPort()             

          #================================================================================

                              
          def configPort(self) :
          
             # configure the serial connections (the parameters differs on the device you are connecting to)
             self.ser_port = serial.Serial()
             self.ser_port.port = self.port_name
             self.ser_port.baudrate=115200
             self.ser_port.parity=serial.PARITY_NONE
             self.ser_port.stopbits=serial.STOPBITS_ONE
             self.ser_port.bytesize = serial.EIGHTBITS #number of bits per bytes
             self.ser_port.xonxoff = False             #disable software flow control
             self.ser_port.rtscts = False              #disable hardware (RTS/CTS) flow control
             self.ser_port.dsrdtr = False              #disable hardware (DSR/DTR) flow control
             self.ser_port.timeout = 1                 #non-block read    
             self.ser_port.writeTimeout = 1            #timeout for write  
             self.ser_port.open()
             
             print("Configured and opened serial port %s\n" % self.ser_port.port)
             
                       
          
          #================================================================================
          
          def write_reg(self,addr,data) : 
          
              data_uint32 = data & 0xffffffff # cast to unsigned 32bit to support negative values
          
              self.ser_port.write(bytearray([self.SU_CMD_WR_WORD]))
              self.ser_port.write(addr.to_bytes(4, byteorder='big'))              
              self.ser_port.write(data_uint32.to_bytes(4, byteorder='big'))
                  
                 
          #================================================================================
          
          def read_reg_unsigned(self,addr) : 
          
              self.ser_port.write(bytearray([self.SU_CMD_RD_WORD]))
              self.ser_port.write(addr.to_bytes(4, byteorder='big'))                     
                
              while (self.ser_port.inWaiting()==0) :
                  serReadChar = self.ser_port.read(1)
                  if (ord(serReadChar)==self.SU_CMD_RSP) :             
                           data = 0 
                           for i in range(4) : # get 4 bytes from serial
                                while (self.ser_port.inWaiting()==0) :  
                                   pass # wait till byte is available
                                data = data*256 + ord(self.ser_port.read(1)) # Compose 32 bit unsigned word value out of the four bytes
                  else :
                     print ("Non Valid read_reg response from FPGA LAB , Quitting");
                  
                  if (data >= 2**31) :   # convert to signed 32 bit integer value         
                     data = -int(((~data)+1) & 0xffffffff)
                  
                  return data
                     
          #================================================================================
          
 
          def read_reg(self,addr) :  # returns signed value , for unsigned call directly read_reg_unsigned
          
               data = self.read_reg_unsigned(addr)
               
               if (data >= 2**31) :   # convert to signed 32 bit integer value         
                  data = -int(((~data)+1) & 0xffffffff)
               
               return data
                     
          #================================================================================
   
 
          def quit(self) :
                 self.ser_port.write("#q\n".encode())
                 self.ser_port.close()
                 quit()       
      


 