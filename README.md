# VoltronGobblers

> Let's Go, Voltron Gobbler Force!

## Overview

Let us introduce VoltronGobblers!

A special kind of Gobblers(about ArtGobblers check this [paper](https://www.paradigm.xyz/2022/09/artgobblers) out). The most special thing about VoltronGobblers is that it can form together, and there will be stronger.

According to the rules of the project party, on the first day, 2,000 whitelist users will claim Gobblers before they can use Goo mint Gobblers. Each Gobblers will be randomly assigned a weight after mint, with a total of four weight levels (6, 7, 8, 9). Weight Multiple will affect the speed of Goo generation. The holder of weight 9 will have a first-mover advantage.

![weight-comparison.png](./analysis/gobblers-price.png)

As shown in the figure above, if there are holders with different weights, on the 10th day, the difference in the number of GOOs received by the holders with the highest and lowest weights will reach an astonishing 50%! To make matters worse, holders with weights below the highest tier may not get Gobblers for a long time after the mint starts.

The blue line in the above picture is the simulated price of gobblers. In the first 3.2 days, no one can afford Gobblers, so the price will drop quickly from the starting price, and the holders of weight 9 can afford it and start generating the first price. gobblers using Goo mint. After the first trade, the price will rise and then fall again, and the holder of the second weight 9 will mint the second goo gobblers, then the third, then the fourth...

According to the probability of the rarity of weight 9, there will be 407 holders of weight 9 among the initial 2000 holders. If they all want to buy the second gobblers, the holders of weight 8 may have to wait until the second month, not to mention holders with lower weights...

So, what should we do?

Let's form together!

The VoltronGobblers can make gobblers holders forming together, and use the higher weight after forming to generate GOO, so that Voltron members can have more gobblers faster.

## How it works

1. users deposit their gobblers in Voltron
2. Voltron will record the goo generated for each user, which is called `virtualBalance`
3. All the goo stored in Voltron are used to mint new gobblers, this can be done with the `mintVoltronGobblers()` function, which can be called by anyone
4. new gobblers in Voltron can be fairly distributed according to the proportion of the number of user's `virtualBalance`

## Quick Start

install

```sh
forge install
```

test

```sh
forge test
```
