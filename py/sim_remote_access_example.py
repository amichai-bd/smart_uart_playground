
import su_sim_remote 
su =  su_sim_remote.su_sim_remote()

su.write(0,0x11223344)
data = su.read(0)
print ("su.read(0) = %x" % data)

su.write(0,0xaabbccdd)
data = su.read(0)
print ("su.read(0) = %x" % data)

su.quit()




