import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import sys, time, math
import serial

xsize=100
ser = serial.Serial(
    port='COM3', # Change as needed
    baudrate=115200,
    parity=serial.PARITY_NONE,
    stopbits=serial.STOPBITS_TWO,
    bytesize=serial.EIGHTBITS
)
ser.isOpen()

def data_gen():
    t = data_gen.t
    val_1 = 0
    val_2 = 0
    val_3 = 0
    while True:
        t+=1
        strin = ser.readline()
    #    temperature_raw = strin.decode('utf-8')
        # val=100.0*math.sin(t*2.0*3.1415/100.0)
        val=float(strin.decode('utf-8'))
        val_average = val
    # Implement Moving average here!
        val_3 = val_2
        val_2 = val_1
        val_1 = val
        
        if val_3 != 0 and t>4:
            val_average = (val_3+val_2+val_1+val)/4


        yield t, val_average

def run(data):
    # update the data
    t,y = data
    if t>-1:
        xdata.append(t)
        ydata.append(y)
        if t>xsize: # Scroll to the left.
            ax.set_xlim(t-xsize, t)
        line.set_data(xdata, ydata)

    return line,

def on_close_figure(event):
    sys.exit(0)

data_gen.t = -1
fig = plt.figure()
fig.canvas.mpl_connect('close_event', on_close_figure)
# Add title and axis names
plt.title('Temperature sensed (degree C) vs. time (s)')
plt.xlabel('Time (s)')
plt.ylabel('Temperature (degrees C)')

ax = fig.add_subplot(111)
line, = ax.plot([], [], lw=2)
ax.set_ylim(22, 35)
ax.set_xlim(0, xsize)
ax.grid()
xdata, ydata = [], []

# Important: Although blit=True makes graphing faster, we need blit=False to prevent
# spurious lines to appear when resizing the stripchart.
ani = animation.FuncAnimation(fig, run, data_gen, blit=False, interval=100, repeat=False)
plt.show()
