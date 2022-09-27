"""
VRGDA price 3D model
"""

import math
import time
from re import X
import matplotlib.pyplot as plt
import numpy as np
from mpl_toolkits.mplot3d import Axes3D
import matplotlib.animation as animation

INITAIL_PRICE = 69.42
MAX_SALES = 200
MAX_DAYS = 15
ANIMATION_MUL = 1
FRAME_PER_SECOND = 24


def compute_vrgda_price(time_since_start, num_sold, initial_price, per_period_price_decrease, logistic_scale, time_scale, time_shift):
    initial_value = logistic_scale / (1 + math.exp(time_scale * time_shift))
    logistic_value = num_sold + initial_value
    price = (1 - per_period_price_decrease) ** (time_since_start - time_shift +
                                                (math.log(-1 + logistic_scale / logistic_value) / time_scale)) * initial_price
    # return math.log(price)
    return price


# X: sold_num
# Y: time
# Z: gobbler price

def generate_graph(x_max, y_max):
    X = []
    Y = []
    Z = []
    P0 = []

    # x_min = 0 if x_max < 50 else round(x_max * 0.8)
    x_min = 0

    for i in range(0, x_max-x_min, 1):
        X.append([])
        Y.append([])
        Z.append([])
        P0.append([])

        # j_start = y_max * 0.8
        j_start = 0
        j = j_start
        while j <= y_max:
            _price = compute_vrgda_price(
                (j + j_start) / ANIMATION_MUL,
                (i+x_min) / ANIMATION_MUL,
                INITAIL_PRICE,  # init price
                0.31,  # Price decay percent.
                6393 * 2,  # Logstic scale L+1
                0.0023,  # Time scale
                0
            )
            
            X[i].append((i+x_min) / ANIMATION_MUL)
            Y[i].append(j / ANIMATION_MUL)

            Z[i].append(_price)
            P0[i].append(INITAIL_PRICE)

            if j == y_max:
                break
            else:
                j = min(j + y_max / FRAME_PER_SECOND, y_max)


    Z = np.array(Z)
    P0 = np.array(P0)

    return X, Y, Z, P0


# Set up plot
fig = plt.figure(figsize=(9, 7))
# ax = fig.add_subplot(projection='3d')
ax = Axes3D(fig)

# Tweak the limits and add latex math labels.
fig.suptitle(r"$logisticVRGDA_{n}(t)$" + "  sales {} days {}".format(MAX_SALES, MAX_DAYS))
ax.set_xlabel(r'Sales (n)')
ax.set_ylabel(r'Time (days)')
ax.set_zlabel(r'Price (Goo)')
# ax.set_zscale('log')

ax.axes.set_xlim3d(left=MAX_SALES, right=0, auto=False)
ax.axes.set_ylim3d(bottom=MAX_DAYS, top=0, auto=False)
ax.axes.set_zlim3d(bottom=0, top=compute_vrgda_price(
    0,
    MAX_SALES,
    INITAIL_PRICE,  # init price
    0.31,  # Price decay percent.
    6393 * 2,  # Logstic scale L+1
    0.0023,  # Time scale
    0
), auto=True)


# X, Y, Z, P0 = generate_graph(20, 20)
# surf = ax.plot_surface(X, Y, Z, cmap=plt.cm.summer, alpha=0.95)
# surf_p0 = ax.plot_surface(X, Y, P0, cmap=plt.cm.Blues_r, alpha=0.2)
# plt.show()

# Begin plotting.
wframe = None
p0 = None
tstart = time.time()
plt.pause(3)
for i in range(1, MAX_SALES * ANIMATION_MUL, 1):
    # If a line collection is already remove it before drawing.
    if wframe:
        wframe.remove()
    # Generate data.
    X, Y, Z, P0 = generate_graph(i, i * (MAX_DAYS / MAX_SALES))
    # Plot the new wireframe and pause briefly before continuing.
    wframe = ax.plot_surface(X, Y, Z, cmap=plt.cm.summer, alpha=0.8)
    # p0 = ax.plot_surface(X, Y, P0, cmap=plt.cm.Blues_r, alpha=0.2)
    plt.pause(.0005)

    if i == MAX_SALES * ANIMATION_MUL - 1:
        plt.show()

print('Average FPS: %f' % (100 / (time.time() - tstart)))
