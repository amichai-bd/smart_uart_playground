import serial.tools.list_ports

def get_usb_serial_port() :

    ports = serial.tools.list_ports.comports()

    usb_ser_port = None

    print ("\nList of active serial ports:\n") 

    for port, desc, hwid in sorted(ports):    
       print("%s ; %s ; %s" % (port, desc, hwid))
       if (desc.find("USB Serial Port")!=-1) :
         usb_ser_port = port
       
    if (usb_ser_port==None) :    
       print ("Sorry, Can't locate a USB serial Port")
    else :
       print ("\nFound USB Serial Port at %s\n" % port)    
    
    return usb_ser_port
    
if __name__ == '__main__':
    
    get_usb_serial_port()