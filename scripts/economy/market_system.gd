## Market system for resource trading between players.
##
## Allows players to buy/sell resources at fluctuating prices based on supply
## and demand. Supports trade routes between markets and AI trading behavior.
class_name MarketSystem
extends Node

# =============================================================================
# Signals
# =============================================================================

signal trade_completed(player_id: int, resource_sold: String, amount_sold: int, resource_bought: String, amount_bought: int)
signal price_changed(resource_type: String, new_price: float)
signal market_created(market_id: int, player_id: int, position: Vector2)

# =============================================================================
# Configuration
# =============================================================================

## Base price for each resource (in gold equivalent).
@export var base_prices: Dictionary = {
	"wood": 10,
	"stone": 15,
	"food": 8,
	"gold": 1,
}

## Price elasticity: how much prices change per trade (0.0-1.0).
@export var price_elasticity: float = 0.05

## Maximum price multiplier (prices can't go above base * this).
@export var max_price_multiplier: float = 3.0

## Minimum price multiplier (prices can't go below base / this).
@export var min_price_multiplier: float = 0.3

## Trade fee percentage (0.0-1.0).
@export var trade_fee: float = 0.1

## Maximum resources per trade.
@export var max_trade_amount: int = 500

## Cooldown between trades for same player (seconds).
@export var trade_cooldown: float = 5.0

# =============================================================================
# Internal State
# =============================================================================

## Current prices for each resource (modified by supply/demand).
var _current_prices: Dictionary = {}

## Trade history: resource_type → total_bought, total_sold
var _trade_volume: Dictionary = {}

## Player trade cooldowns: player_id → time_remaining
var _cooldowns: Dictionary = {}

## Active markets: market_id → { player_id, position, is_active }
var _markets: Dictionary = {}
var _next_market_id: int = 0

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_initialize_prices()
	if not EventBus.game_started.is_connected(_on_game_started):
		EventBus.game_started.connect(_on_game_started)


func _process(delta: float) -> void:
	# Update cooldowns.
	var to_remove: Array[int] = []
	for pid: int in _cooldowns:
		_cooldowns[pid] -= delta
		if _cooldowns[pid] <= 0.0:
			to_remove.append(pid)
	for pid: int in to_remove:
		_cooldowns.erase(pid)

	# Periodically rebalance prices.
	if Engine.get_process_frames() % 300 == 0:  # Every 5 seconds at 60fps
		_rebalance_prices()

# =============================================================================
# Initialization
# =============================================================================

func _on_game_started(_player_id: int) -> void:
	_initialize_prices()


func _initialize_prices() -> void:
	_current_prices = base_prices.duplicate()
	_trade_volume.clear()
	for resource_type: String in base_prices:
		_trade_volume[resource_type] = {"bought": 0, "sold": 0}

# =============================================================================
# Market Management
# =============================================================================

## Create a new market building. Returns market_id.
func create_market(player_id: int, position: Vector2) -> int:
	var market_id: int = _next_market_id
	_next_market_id += 1

	_markets[market_id] = {
		"player_id": player_id,
		"position": position,
		"is_active": true,
		"trade_count": 0,
	}

	market_created.emit(market_id, player_id, position)
	return market_id


## Remove a market.
func remove_market(market_id: int) -> void:
	_markets.erase(market_id)


## Get all markets for a player.
func get_player_markets(player_id: int) -> Array:
	var result: Array = []
	for market_id: int in _markets:
		var market: Dictionary = _markets[market_id]
		if market["player_id"] == player_id and market["is_active"]:
			result.append({"id": market_id, "position": market["position"]})
	return result


## Get nearest market to a position for a player.
func get_nearest_market(player_id: int, position: Vector2) -> Dictionary:
	var best_market: Dictionary = {}
	var best_dist: float = INF

	for market_id: int in _markets:
		var market: Dictionary = _markets[market_id]
		if market["player_id"] != player_id or not market["is_active"]:
			continue
		var dist: float = position.distance_to(market["position"])
		if dist < best_dist:
			best_dist = dist
			best_market = {"id": market_id, "position": market["position"], "distance": dist}

	return best_market

# =============================================================================
# Trading
# =============================================================================

## Sell resources and buy another. Returns true if trade succeeded.
func trade(player_id: int, resource_sold: String, amount_sold: int, resource_bought: String) -> Dictionary:
	var result: Dictionary = {"success": false, "message": ""}

	# Validate inputs.
	if resource_sold == resource_bought:
		result["message"] = "Cannot trade same resource"
		return result

	if amount_sold <= 0 or amount_sold > max_trade_amount:
		result["message"] = "Invalid trade amount"
		return result

	# Check cooldown.
	if _cooldowns.has(player_id):
		result["message"] = "Trade on cooldown"
		return result

	# Check if player has enough resources.
	var rm: Node = _find_resource_manager()
	if rm == null:
		result["message"] = "ResourceManager not found"
		return result

	var available: int = rm.get_resource_amount(resource_sold, player_id)
	if available < amount_sold:
		result["message"] = "Insufficient %s (have %d, need %d)" % [resource_sold, available, amount_sold]
		return result

	# Calculate buy amount.
	var sell_price: float = _get_price(resource_sold)
	var buy_price: float = _get_price(resource_bought)
	var gold_value: float = float(amount_sold) * sell_price
	var fee: float = gold_value * trade_fee
	var net_value: float = gold_value - fee
	var amount_bought: int = int(net_value / buy_price)

	if amount_bought <= 0:
		result["message"] = "Trade not profitable"
		return result

	# Execute trade.
	rm.spend({resource_sold: amount_sold}, player_id)
	rm.add_resource_direct(resource_bought, amount_bought, player_id)

	# Update prices and volume.
	_update_trade_volume(resource_sold, amount_sold, true)
	_update_trade_volume(resource_bought, amount_bought, false)
	_update_price(resource_sold)
	_update_price(resource_bought)

	# Set cooldown.
	_cooldowns[player_id] = trade_cooldown

	result["success"] = true
	result["amount_bought"] = amount_bought
	result["fee_paid"] = int(fee)

	trade_completed.emit(player_id, resource_sold, amount_sold, resource_bought, amount_bought)
	return result


## Get the current sell price for a resource.
func get_sell_price(resource_type: String) -> float:
	return _get_price(resource_type)


## Get the current buy price for a resource.
func get_buy_price(resource_type: String) -> float:
	return _get_price(resource_type) * (1.0 + trade_fee)


## Calculate how much of resource_bought the player would get for amount_sold.
func calculate_trade(resource_sold: String, amount_sold: int, resource_bought: String) -> Dictionary:
	if resource_sold == resource_bought:
		return {"amount_bought": 0, "fee": 0}

	var sell_price: float = _get_price(resource_sold)
	var buy_price: float = _get_price(resource_bought)
	var gold_value: float = float(amount_sold) * sell_price
	var fee: float = gold_value * trade_fee
	var net_value: float = gold_value - fee
	var amount_bought: int = int(net_value / buy_price)

	return {
		"amount_bought": amount_bought,
		"fee": int(fee),
		"sell_price": sell_price,
		"buy_price": buy_price,
	}

# =============================================================================
# Price System
# =============================================================================

func _get_price(resource_type: String) -> float:
	return _current_prices.get(resource_type, base_prices.get(resource_type, 10))


func _update_price(resource_type: String) -> void:
	var volume: Dictionary = _trade_volume.get(resource_type, {"bought": 0, "sold": 0})
	var bought: int = volume["bought"]
	var sold: int = volume["sold"]

	# Price goes up when more bought, down when more sold.
	var supply_demand: float = 1.0
	if bought + sold > 0:
		supply_demand = float(sold) / float(bought + sold)

	var base: float = base_prices.get(resource_type, 10)
	var new_price: float = base * (0.5 + supply_demand)
	new_price = clampf(new_price, base / max_price_multiplier, base * max_price_multiplier)

	if not is_equal_approx(_current_prices[resource_type], new_price):
		_current_prices[resource_type] = new_price
		price_changed.emit(resource_type, new_price)


func _rebalance_prices() -> void:
	# Slowly move prices back towards base.
	for resource_type: String in _current_prices:
		var current: float = _current_prices[resource_type]
		var base: float = base_prices.get(resource_type, 10)
		var diff: float = base - current
		_current_prices[resource_type] = current + diff * 0.1  # 10% rebalance per tick


func _update_trade_volume(resource_type: String, amount: int, is_sell: bool) -> void:
	if not _trade_volume.has(resource_type):
		_trade_volume[resource_type] = {"bought": 0, "sold": 0}

	if is_sell:
		_trade_volume[resource_type]["sold"] += amount
	else:
		_trade_volume[resource_type]["bought"] += amount

# =============================================================================
# AI Trading Helpers
# =============================================================================

## Get the best resource to sell for a player (most abundant).
func get_best_sell_resource(player_id: int) -> String:
	var rm: Node = _find_resource_manager()
	if rm == null:
		return "wood"

	var resources: Dictionary = rm.get_all_resources(player_id)
	var best_resource: String = "wood"
	var best_amount: int = 0

	for resource_type: String in resources:
		if resource_type == "gold":
			continue  # Don't sell gold directly.
		var amount: int = resources[resource_type]
		if amount > best_amount:
			best_amount = amount
			best_resource = resource_type

	return best_resource


## Get the best resource to buy for a player (most needed).
func get_best_buy_resource(player_id: int) -> String:
	var rm: Node = _find_resource_manager()
	if rm == null:
		return "gold"

	var resources: Dictionary = rm.get_all_resources(player_id)
	var best_resource: String = "gold"
	var best_deficit: int = 0

	# Check what's lowest relative to a target of 200.
	for resource_type: String in base_prices:
		var amount: int = resources.get(resource_type, 0)
		var deficit: int = maxi(200 - amount, 0)
		if deficit > best_deficit:
			best_deficit = deficit
			best_resource = resource_type

	return best_resource


## Should the AI trade? Returns true if trading would be beneficial.
func should_ai_trade(player_id: int) -> bool:
	var rm: Node = _find_resource_manager()
	if rm == null:
		return false

	var resources: Dictionary = rm.get_all_resources(player_id)

	# Trade if any resource is very high (>500) and another is very low (<100).
	for sell_res: String in resources:
		if sell_res == "gold":
			continue
		if resources[sell_res] > 500:
			for buy_res: String in base_prices:
				if buy_res != sell_res and resources.get(buy_res, 0) < 100:
					return true

	return false

# =============================================================================
# Helpers
# =============================================================================

func _find_resource_manager() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("ResourceManager")


func get_all_prices() -> Dictionary:
	return _current_prices.duplicate()


func get_market_count(player_id: int) -> int:
	var count: int = 0
	for market_id: int in _markets:
		if _markets[market_id]["player_id"] == player_id and _markets[market_id]["is_active"]:
			count += 1
	return count
