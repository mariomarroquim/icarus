require_relative 'general_strategy'

class NextProfitStrategy < GeneralStrategy
  VOLUME_MARGIN = 0.200
  PROFIT_MARGIN = 1.010 # HIGH / LAST
  LOSS_MARGIN   = 0.950 # LOW / HIGH

  def execute!
    make_a_new_buy = true
    made_loss = false

    while(true) do
      sleep 3

      if make_a_new_buy == true
        last_sell = updated_last_order

        if last_sell != nil && last_sell.status == 'canceled'
          make_a_new_buy = false
          logger.puts '[OK] Previous sell not closed. Trying again!'
          next

        elsif last_sell != nil && last_sell.status != 'closed'
          logger.puts '[OK] Waiting for the last sell to be placed'
          next

        elsif last_sell != nil && made_loss == true
          logger.puts '[FAILSAFE] Exiting market!'
          exit
        end

        logger.puts '[OK] Trying a new buy...'

        current_volume = available_funds[:zeur] / medium_sell_price
        current_volume = current_volume * VOLUME_MARGIN

        place_order('buy', current_volume, nil, nil)
        make_a_new_buy = false

        logger.puts "[OK] Buying #{current_volume}! <=="
      else
        last_buy = updated_last_order

        if last_buy.status == 'canceled'
          make_a_new_buy = true
          logger.puts '[OK] Previous buy not closed. Trying again!'
          next

        elsif last_buy.status != 'closed'
          logger.puts '[OK] Waiting for the last buy to be placed'
          next
        end

        last_volume   = last_buy.vol_exec.to_f
        last_price    = last_buy.price.to_f
        current_price = highest_buy_price(current_volume)

        made_profit = current_price > (last_price * PROFIT_MARGIN)
        made_loss   = current_price <= (last_price * LOSS_MARGIN)

        if made_profit || made_loss
          place_order('sell', last_volume, nil, nil)
          make_a_new_buy = true

          logger.puts "[OK] Selling #{last_volume}! <=="
        else
          logger.puts '.'
        end
      end
    end
  end
end

NextProfitStrategy.new.execute!
