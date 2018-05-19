--== Payment Processing Functions ==--

local messages = {
  overpaid = "message=You paid {amount} KST more than you should have, here is your change, {buyer}.",
  underpaid = "error=You must pay at least {price} KST for {item}(s), you have been refunded, {buyer}.",
  outOfStock = "error=We do not have any {item}(s) at the moment, sorry for any inconvenience, {buyer}.",
  unknownItem = "error=We do not currently sell {item}(s), sorry for any inconvenience, {buyer}."
}

if config.messages then
  for k, v in config.messages do
    messages[k] = v
  end
end

local function escapeSemi(txt)
  return txt:gsub("[%;%=]", "")
end

local function template(str, context)
  for k, v in pairs(context) do
    str = str:gsub("{" .. k .. "}", v)
  end

  return str
end

local function processPayment(tx, meta)
  local item, mcname = findItem(meta.name)

  if item then
    local count = math.floor(tonumber(tx.value) / item.price)

    local ac = math.min(count, list[mcname] or 0)
    if ac > 0 then
      logger.info("Dispensing " .. count .. " " .. item.disp .. "(s)")
      logger.info("Xenon (" .. (config.title or "Shop") .. "): " ..
          (meta.meta and meta.meta["username"] or "Someone") .. " bought " .. ac .. " " .. item.disp .. "(s) (" .. (ac * item.price) .. " KST)!",
        (config.logger or {}).purchase or false)
    end

    if (list[mcname] or 0) < count then
      logger.warn("More items were requested than available, refunding..")

      if (list[mcname] ~= 0) then
        logger.warn("Xenon (" .. (config.title or "Shop") .. "): " ..
            (meta.meta and meta.meta["username"] or "Someone") .. " bought all remaining " .. item.disp .. "(s), they are now out of stock.",
          (config.logger or {}).outOfStock or false)
      end

      if meta.meta and meta.meta["return"] then
        local refundAmt = math.floor(tx.value - (list[mcname] * item.price))

        if ac == 0 then
          await(kapi.makeTransaction, config.pkey, meta.meta["return"], refundAmt,
            template(messages.outOfStock, { item = item.disp, price = item.price, amount = refundAmt, buyer = (meta.meta and meta.meta["username"] or "Someone") }))
        else
          await(kapi.makeTransaction, config.pkey, meta.meta["return"], refundAmt,
            template(messages.overpaid, { item = item.disp, price = item.price, amount = refundAmt, buyer = (meta.meta and meta.meta["username"] or "Someone") }))
        end
      end
      count = list[mcname]
      tx.value = math.ceil(list[mcname] * item.price)
    end

    if tx.value < item.price then
      local refundAmt = tx.value

      await(kapi.makeTransaction, config.pkey, meta.meta["return"], refundAmt,
        template(messages.underpaid, { item = item.disp, amount = refundAmt, price = item.price, buyer = (meta.meta and meta.meta["username"] or "Someone") }))
    elseif tx.value > count * item.price then
      if meta.meta and meta.meta["return"] then
        local refundAmt = tx.value - (count * item.price)

        if refundAmt >= 1 then
          await(kapi.makeTransaction, config.pkey, meta.meta["return"], refundAmt,
            template(messages.overpaid, { item = item.disp, amount = refundAmt, price = item.price, buyer = (meta.meta and meta.meta["username"] or "Someone") }))
        end
      end
    end

    if list[mcname] and list[mcname] ~= 0 then
      dispense(mcname, count)
    end
  else
    logger.warn("Payment was sent for an invalid item (" .. meta.name .. "), aborting..")
    if meta.meta and meta.meta["return"] then
      await(kapi.makeTransaction, config.pkey, meta.meta["return"], tx.value,
        template(messages.unknownItem, { item = escapeSemi(meta.name), amount = refundAmt, buyer = (meta.meta and meta.meta["username"] or "Someone") }))
    end
  end
end
