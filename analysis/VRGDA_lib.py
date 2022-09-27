import math

"""
GOO
"""


def compute_goo_balance(emission_multiple, last_balance, time_elapsed):
    t1 = math.sqrt(emission_multiple) * time_elapsed + \
        2 * math.sqrt(last_balance)
    final_amount = 0.25 * t1 * t1

    return final_amount


"""
Gobblers
"""


class Pricer:

    def compute_gobbler_price(self, time_since_start, num_sold, initial_price, per_period_price_decrease, logistic_scale, time_scale, time_shift):
        return self.compute_vrgda_price(time_since_start, num_sold, initial_price, per_period_price_decrease, logistic_scale, time_scale, time_shift)

    def compute_page_price(self, time_since_start, num_sold, initial_price, per_period_price_decrease, logistic_scale, time_scale, time_shift,  per_period_post_switchover, switchover_time):
        initial_value = logistic_scale / \
            (1 + math.exp(time_scale * time_shift))
        sold_by_switchover = logistic_scale / \
            (1 + math.exp(-1 * time_scale * (switchover_time - time_shift))) - initial_value
        if num_sold < sold_by_switchover:
            return self.compute_vrgda_price(time_since_start, num_sold, initial_price, per_period_price_decrease, logistic_scale, time_scale, time_shift)
        else:
            f_inv = (num_sold - sold_by_switchover) / \
                per_period_post_switchover + switchover_time
            return initial_price * math.exp(-math.log(1 - per_period_price_decrease) * (f_inv - time_since_start))

    def compute_vrgda_price(self, time_since_start, num_sold, initial_price, per_period_price_decrease, logistic_scale, time_scale, time_shift):
        initial_value = logistic_scale / \
            (1 + math.exp(time_scale * time_shift))
        logistic_value = num_sold + initial_value
        price = (1 - per_period_price_decrease) ** (time_since_start - time_shift +
                                                    (math.log(-1 + logistic_scale / logistic_value) / time_scale)) * initial_price
        return price


class Holder():
    '''whitelist holder'''

    def __init__(self, m):
        self.m = m
        self.m0 = m
        self.balance = 0  # goo
        self.cost = 0
        self.gobblers = 1
        self.last_update_time = 0  # day
        pass

    def update_balance(self, time_from_revealed):
        time_elapsed = time_from_revealed - self.last_update_time
        # Revealed should after mint_start (a day)
        if time_elapsed > 0:
            self.balance = compute_goo_balance(
                self.m, self.balance, time_elapsed)
            self.last_update_time = time_from_revealed

    def buy_gobblers(self, price, m):
        if (self.balance >= price):
            self.balance -= price
            self.m += m
            self.cost += price
            self.gobblers += 1


class ArtGobblers():
    def __init__(self, ):
        self.pricer = Pricer()
        self.last_price = 69.42
        self.num_sold = 0
        pass

    def calculate_gobblers_price(self, time_since_start):
        return self.pricer.compute_gobbler_price(
            time_since_start,
            self.num_sold+1,
            69.42,  # init price
            0.31,  # Price decay percent.
            6393 * 2,  # Logstic scale L+1
            0.0023,  # Time scale
            0
        )

    def update(self, time_since_start):
        self.last_price = self.calculate_gobblers_price(time_since_start)

    def mint_from_goo(self, buyer, time_since_start):
        self.update(time_since_start)
        self.num_sold += 1
        # avg multiple is 7.33
        buyer.buy_gobblers(self.last_price, m=7.33)
        print("day {:.2f} mint_from_goo price {:.4f} buyer m0 {} m {} gobblers {} balance {:.4f} total cost {:.4f}".format(
            time_since_start, self.last_price, buyer.m0, buyer.m, buyer.gobblers, buyer.balance, buyer.cost))
        self.update(time_since_start)
