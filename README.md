# narrow

Experiment.
Don't use this.

# How to use.

```coffeescript
demoNormalUse = ->
  new Narrow().setItems([1..3])

demoSyncProvider = ->
  provider = getItems: ->
    ['a', 'b', 'c']
  Narrow.fromProvider(provider)

demoAsyncProvider = ->
  asyncProvider =
    getItems: ->
      new Promise (resolve) ->
        setTimeout((-> resolve(['d', 'e', 'f'])), 1000)
  Narrow.fromProvider(asyncProvider)

demoNormalUse()
demoSyncProvider()
demoAsyncProvider()
```
