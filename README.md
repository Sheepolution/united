# United

United is an entity state manager that allows you to work with multiple states at the same time.

## Installation

The united.lua file should be dropped into an existing project and required by it.

```lua
united = require "united"
```

You can then use `united` to create a new state manager with `united.new(entity, ...)`, where you pass the entity you want to use it with, and the state types.

### Creating state types

You can create state types using `united.enum`.

```lua
local action = united.enum { "Idle", "Walk", "Run", "Jump" }
local position = united.enum { "Ground", "Air" }
```

We can then pass these state types when creating a new state manager.

```lua
self.sm = united.new(self, action, position)
```

The first state type passed will function as the default state for all functions where it is optional to pass them.

You can use the same name in two differen state types without issue.

```lua
local status = united.enum { "Good", "Bad" }
local mood = united.enum { "Good", "Bad" }
print(status.Good == mood.Good) -- Output: false
```

## Configure

We can configure the state manager using `sm:configure(configuration)`.

```lua
self.sm:configure({
    -- You can only go to the Idle state when on the ground
    [action.Idle] = {[position.Ground] = true} 

    -- You cannot go into the Run state while in the Jump state.
    [action.Run] = {[action.Jump] = false} 
})
```

## Switching to a state

You can switch to a state using `sm:to(state, [ignore])`.

```lua
self.sm:to(action.Run)
```

There are a number of checks to see if the state can be changed. The configuration is one of those checks. Another check is the check-method.

## State methods

You can add methods to a state by adding a table to the state. There are three type of methods.

* Check - Called to see if this can become the current state.
* Enter - Called when the state becomes the current state.
* Update - Called every frame when the state is the current state.
* Exit - Called when the state has changed into another state.

These methods are to be named in the following way: `[stateName][Method]`

For example:

```lua
function Entity:jumpCheck()
	return self.unlockedJumping
end

function Entity:jumpEnter()
	self:playSound("jump")
end

function Entity:jumpUpdate(deltatime)
	self:playAnimation(deltatime, "jump")
end

function Entity:jumpExit()
	self:playSound("land")
end
```

## Methods

`sm:update(deltatime)`

Update the current states.

___

`sm:setCallback(f, [stateType])`

Set a callback that is called whenever a state of the passed state type changes. If no state type is given, the callback is set for all state types.

> Returns self for chaining.

___

`sm:to(state, [ignore])`

Change the current state to the passed state. If the state is not allowed, the state will not change.

If the ignore parameter is set to true, the state will change regardless of the configuration or locking.

You can also ignore specific checks by passing a table with the state types you want to ignore, using `united.ignore`.

* `united.ignore.all` - Ignore all checks. Same as passing true.
* `united.ignore.config` - Ignore the configuration. (e.g. go into the idle state while in the air)
* `united.ignore.lock` - Ignore the lock on the state type. Removes the lock.
* `united.ignore.check` - Ignore the check-method.
* `united.ignore.current` - Ignore that the state is already the current state. The init callback will be called again.

These types can be passed individually, or combined using a hash table.

```lua
self.sm:to(action.Run, united.ignore.lock)
self.sm:to(action.Run, {
	[united.ignore.config] = true,
	[united.ignore.check] = true
})
```

> Returns true if the state was changed, false otherwise.

___

`sm:push(state, [ignore])`

Same as `sm:to(state, ignore)`. Push a state onto the stack. The state will be the current state until it is popped.

> Returns true if the state was changed, false otherwise.

___

`sm:pop([stateType])`

Pop the current state from the stack. The previous state will become the current state.

If no state type is passed, the default state type is used.

Ignores all checks to pop into the previous state.

> Returns true if there was a state on the stack to pop, false otherwise.

___

`sm:get([stateType])`

Get the current state based on the given state type. If no state type is given, the default state type is used.

> Returns the current state.
___

`sm:key([stateType])`

Get the name of the current state based on the given state type. If no state type is given, the default state type is used.

The key is what is used to get the value of the state type, which is not identical to the key. The value has a unique number attached to it.

> Returns the key of the current state.
___

`sm:is(state)`

Check if the passed state is the current state of its corresponding state type.

> Returns true if the passed state is the current state, false otherwise.
___ 

1. `sm:lock(state)`
2. `sm:lock([stateType])`

Locks the state so that it cannot be changed until it is unlocked, unless forced through using the ignore parameter, or when popping into the previous state.

1. Lock the given state, but only when it is the current state of that state type.
> Returns true if the state was locked successfully, false otherwise.

2. Lock the current state of the state type. If no state is given, the default state type is used.
> Returns true

___

1. `sm:unlock(state)`
2. `sm:unlock([stateType])`

Unlocks the state.

1. Unlock the given state, but only when it is the current state of that state type.
> Returns true if the state was unlocked successfully, false otherwise.

2. Unlock the state type. If no state is given, the default state type is used.
> Returns true

## License

This library is free software; you can redistribute it and/or modify it under the terms of the MIT license. See [LICENSE](LICENSE) for details.