noflo = require 'noflo'

class GetObjectKey extends noflo.Component
  icon: 'indent'
  constructor: ->
    @sendGroup = true
    @data = []
    @key = []

    @inPorts =
      in: new noflo.Port 'object'
      key: new noflo.ArrayPort 'string'
      sendgroup: new noflo.Port 'boolean'
    @outPorts =
      out: new noflo.Port 'all'
      object: new noflo.Port 'object'
      missed: new noflo.Port 'object'

    @inPorts.in.on 'connect', =>
      @data = []
    @inPorts.in.on 'begingroup', (group) =>
      @outPorts.out.beginGroup group
    @inPorts.in.on 'data', (data) =>
      return @getKey data if @key.length
      @data.push data
    @inPorts.in.on 'endgroup', =>
      @outPorts.out.endGroup()
    @inPorts.in.on 'disconnect', =>
      unless @data.length
        # Data already sent
        @outPorts.out.disconnect()
        return
      
      # No key, data will be sent when we get it
      return unless @key.length

      # Otherwise send data we have an disconnect
      @getKey data for data in @data
      @outPorts.out.disconnect()
      @outPorts.object.disconnect() if @outPorts.object.isAttached()

    @inPorts.key.on 'data', (data) =>
      @key.push data
    @inPorts.key.on 'disconnect', =>
      return unless @data.length

      @getKey data for data in @data
      @data = []
      @outPorts.out.disconnect()

    @inPorts.sendgroup.on 'data', (data) =>
      @sendGroup = String(data) is 'true'

  error: (data, error) ->
    if @outPorts.missed.isAttached()
      @outPorts.missed.send data
      @outPorts.missed.disconnect()
      return
    throw error

  getKey: (data) ->
    unless @key.length
      @error data, new Error 'Key not defined'
      return
    unless typeof data is 'object'
      @error data, new Error 'Data is not an object'
      return
    if data is null
      @error data, new Error 'Data is NULL'
      return
    for key in @key
      if data[key] is undefined
        @error data, new Error "Object has no key #{key}"
        continue
      @outPorts.out.beginGroup key if @sendGroup
      @outPorts.out.send data[key]
      @outPorts.out.endGroup() if @sendGroup

    return unless @outPorts.object.isAttached()
    @outPorts.object.send data

exports.getComponent = -> new GetObjectKey
