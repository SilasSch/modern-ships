extends GutTest


func test_pool_caps_and_recycles() -> void:
	var p := FxPool.new(8)
	var first := p.acquire()
	for i in 11:
		p.acquire()
	assert_eq(p.active_count(), 8)


func test_recycles_oldest_slot() -> void:
	var p := FxPool.new(2)
	var a := p.acquire()
	var b := p.acquire()
	assert_ne(a, b)
	assert_eq(p.acquire(), a, "full pool hands out the oldest slot again")


func test_release_frees_slot() -> void:
	var p := FxPool.new(2)
	var a := p.acquire()
	p.acquire()
	p.release(a)
	assert_eq(p.active_count(), 1)
	assert_eq(p.acquire(), a)
