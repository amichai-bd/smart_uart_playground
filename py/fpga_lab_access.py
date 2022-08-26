import sys

def get_port() :

    if (len(sys.argv) < 2) :
       print("Missing Port Argument, please provide either SIM for simulation or COM for FPGA")
       quit() 
    
    if (sys.argv[1]=="SIM") :
        import fpga_lab_access_sim as fla
        port = fla.port()
    else :
        import fpga_lab_access_com as fla    
        port = fla.port()        
        
    return port
    
    
    
    
    