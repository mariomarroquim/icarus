require 'kraken_client'

class GeneralStrategy
  attr_accessor :client, :last_order_id, :logger

  def initialize
    KrakenClient.configure do |config|
      config.api_key     = 'XXX'
      config.api_secret  = 'XXX'
      config.base_uri    = 'https://api.kraken.com'
      config.api_version = 0
      config.limiter     = false
      config.tier        = 3
    end

    self.client = KrakenClient.load

    self.logger = File.open('transactions.txt', 'w')
    self.logger.sync = true
  end

  def available_funds
    funds = client.private.balance
    { zeur: funds.ZEUR.to_f, coin: funds.XETH.to_f }
  rescue
    logger.puts '[ERROR] Unavailable service (1). Trying again!'
    sleep 3
    available_funds
  end

  def medium_sell_price
    client.public.ticker('ETHEUR').XETHZEUR.a.first.to_f
  rescue
    logger.puts '[ERROR] Unavailable service (2). Trying again!'
    sleep 3
    medium_sell_price
  end

  def lowest_sell_price(volume=nil)
    orders = client.public.order_book('ETHEUR').XETHZEUR

    if volume == nil
      orders.asks.sort_by{ |ask| ask[0] }[0][0].to_f
    else
      orders.asks.select{ |ask| ask[1].to_f >= volume }.sort_by{ |ask| ask[0] }[0][0].to_f
    end
  rescue
    logger.puts '[ERROR] Unavailable service (3). Trying again!'
    sleep 3
    lowest_sell_price(volume)
  end

  def highest_buy_price(volume=nil)
    orders = client.public.order_book('ETHEUR').XETHZEUR

    if volume == nil
      orders.bids.sort_by{ |bid| bid[0] }[-1][0].to_f
    else
      orders.bids.select{ |bid| bid[1].to_f >= volume }.sort_by{ |bid| bid[0] }[-1][0].to_f
    end
  rescue
    logger.puts '[ERROR] Unavailable service (4). Trying again!'
    sleep 3
    highest_buy_price(volume)
  end

  def place_order(type, volume, price=nil, profit=nil)
    options = { pair: 'ETHEUR', type: type, volume: volume }

    if price == nil
      options.merge!(ordertype: 'market')
    else
      options.merge!(ordertype: 'take-profit', price: price)
    end

    if profit != nil
      options.merge!('close[ordertype]': 'take-profit', 'close[price]': profit)
    end

    self.last_order_id = client.private.add_order(options).txid[0]
    sleep 11
  rescue
    if !has_open_orders?
      logger.puts '[ERROR] Unavailable service (5). Trying again!'
      sleep 3
      place_order(type, volume, price, profit)
    else
      self.last_order_id = last_closed_order_id
    end
  end

  def last_closed_order_id
    client.private.closed_orders.closed.first[0]
  rescue
    logger.puts '[ERROR] Unavailable service (6). Trying again!'
    sleep 3
    last_closed_order_id
  end

  def has_open_orders?
    !client.private.open_orders.open.empty?
  rescue
    logger.puts '[ERROR] Unavailable service (7). Trying again!'
    sleep 3
    has_open_orders?
  end

  def updated_last_order
    return nil if last_order_id == nil

    client.private.query_orders(txid: last_order_id).send(last_order_id)
  rescue
    logger.puts '[ERROR] Unavailable service (8). Trying again!'
    sleep 3
    updated_last_order
  end
end
