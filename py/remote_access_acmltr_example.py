
import sys
import random
import fpga_lab_access as fla

#===============================================================================================

# Main

port  = fla.get_port()

# Agreed values
addMode = 0 ;
subMode = 1 ;
valWrRegIdx = 0 ;
modeWrRegIdx = 1 ;
acmltrRdRegIdx = 0 ;

def acmltr_add_val(val) :   # Add value to Accumulator
   port.write_reg(modeWrRegIdx,addMode)   # set mode to add reg #1 to accumulator
   port.write_reg(valWrRegIdx,val) # write reg #0
   acmltr = port.read_reg(acmltrRdRegIdx)
   print ("+%-2d : acmltr = %2d" % (val,acmltr))
   

def acmltr_sub_val(val) :   # Sub value from Accumulator
   port.write_reg(modeWrRegIdx,subMode)   # set mode to subtract reg #1 from accumulator
   port.write_reg(valWrRegIdx,val) # write reg #0
   acmltr = port.read_reg(acmltrRdRegIdx)
   print ("-%-2d : acmltr = %2d" % (val,acmltr))

# main
   
for i in range(10) :  # Test for some iterations

     randBin = random.randint(0,1)
     val = random.randint(0,9)
     
     if (randBin==0) :
       acmltr_add_val(val)
     else :
       acmltr_sub_val(val)

port.quit()
     

 



