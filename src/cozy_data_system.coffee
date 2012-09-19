Client = require("request-json").JsonClient

exports.initialize = (schema, callback) ->
  schema.adapter = new exports.CozyDataSystem()
  process.nextTick(callback)


class exports.CozyDataSystem

    constructor: ->
        @_models = {}
        @client = new Client "http://localhost:7000/"

    # Register Model to adapter and define extra methods
    define: (descr) ->
        @_models[descr.model.modelName] = descr

        descr.model.search = (query, callback) =>
            @search descr.model.modelName, query, callback
        descr.model.defineRequest = (name, map, callback) =>
            @defineRequest descr.model.modelName, name, map, callback
        descr.model.request = (name, params, callback) =>
            @request descr.model.modelName, name, params, callback
        descr.model.removeRequest = (name, callback) =>
            @removeRequest descr.model.modelName, name, callback
        descr.model.requestDestroy = (name, params, callback) =>
            @requestDestroy descr.model.modelName, name, params, callback

        descr.model::index = (fields, callback) ->
            @_adapter().index @, fields, callback
        descr.model::attachFile = (path, callback) ->
            @_adapter().attachFile  @, path, callback
        descr.model::getFile = (path, callback) ->
            @_adapter().getFile  @, path, callback
        descr.model::saveFile = (path, filePath, callback) ->
            @_adapter().saveFile  @, path, filePath, callback
        descr.model::removeFile = (path, callback) ->
            @_adapter().removeFile  @, path, callback

    # Check existence of model in the data system.
    exists: (model, id, callback) ->
        @client.get "data/exist/#{id}/", (error, response, body) =>
            if error
                callback error
            else if not body? or not body.exist?
                callback new Error("Data system returned invalid data.")
            else
                callback null, body.exist

    # Find a doc with its ID. Returns it if it is found else it
    # returns null
    find: (model, id, callback) ->
         @client.get "data/#{id}/", (error, response, body) =>
            if error
                callback error
            else if response.statusCode == 404
                callback null, null
            else if body.docType != model
                callback null, null
            else
                callback null, new @_models[model].model(body)

    # Create a new document from given data. If no ID is set a new one
    # is automatically generated.
    create: (model, data, callback) ->
        path = "data/"
        if data.id?
            path += "#{data.id}/"
            delete data.id
        data.docType = model
        @client.post path, data, (error, response, body) =>
            if error
                callback error
            else if response.statusCode == 409
                callback new Error("This document already exists")
            else if response.statusCode != 201
                callback new Error("Server error occured.")
            else
                callback null, body._id

    # Save all model attributes to DB.
    save: (model, data, callback) ->
        data.docType = model
        @client.put "data/#{data.id}/", data, (error, response, body) =>
            if error
                callback error
            else if response.statusCode == 404
                callback new Error("Document not found")
            else if response.statusCode != 200
                callback new Error("Server error occured.")
            else
                callback()

    # Save only given attributes to DB.
    updateAttributes: (model, id, data, callback) ->
        @client.put "data/merge/#{id}/", data, (error, response, body) =>
            if error
                callback error
            else if response.statusCode == 404
                callback new Error("Document not found")
            else if response.statusCode != 200
                callback new Error("Server error occured.")
            else
                callback()

    # Save only given attributes to DB. If model does not exist it is created.
    # It requires an ID.
    updateOrCreate: (model, data, callback) ->
        data.docType = model
        @client.put "data/upsert/#{data.id}/", data, (error, response, body) =>
            if error
                callback error
            else if response.statusCode != 200 and response.statusCode != 201
                callback new Error("Server error occured.")
            else if response.statusCode == 200
                callback null
            else if response.statusCode == 201
                callback null, body._id


    # Destroy model in database.
    # Call method like this:
    #     note = new Note id: 123
    #     note.destroy ->
    #         ...
    destroy: (model, id, callback) ->
        @client.del "data/#{id}/", (error, response, body) =>
            if error
                callback error
            else if response.statusCode == 404
                callback new Error("Document not found")
            else if response.statusCode != 204
                callback new Error("Server error occured.")
            else
                callback()

    # index given fields of model instance inside cozy data indexer.
    # it requires that note is saved before indexing, else it won't work
    # properly (it took data from db).
    # ex: note.index ["content", "title"], (err) ->
    #  ...
    #
    index: (model, fields, callback) ->
        data =
            fields: fields
        @client.post "data/index/#{model.id}", data, (error, response, body) =>
            if error
                callback error
            else if response.statusCode != 200
                callback new Error(body)
            else
                callback null

    # Retrieve note through index. Give a query then grab results. 
    # ex: Note.search "dragon", (err, docs) ->
    # ...
    #
    search: (model, query, callback) ->
        data =
            query: query

        @client.post "data/search/#{model.toLowerCase()}", data, \
                     (error, response, body) =>
            if error
                callback error
            else if response.statusCode != 200
                callback new Error(body)
            else
                results = []
                for doc in body.rows
                    results.push new @_models[model].model(doc)
                callback null, results

    # Save a file into data system and attach it to current model.
    attachFile: (model, path, callback) ->
        urlPath = "data/#{model.id}/attachments/"
        @client.sendFile urlPath, path, (error, response, body) =>
            @checkError error, response, body, 201, callback

    # Get file stream of given file for given model from data system
    getFile: (model, path, callback) ->
        urlPath = "data/#{model.id}/attachments/#{path}"
        @client.get urlPath, (error, response, body) =>
            @checkError error, response, body, 200, callback

    # Save to disk given file for given model from data system
    saveFile: (model, path, filePath, callback) ->
        urlPath = "data/#{model.id}/attachments/#{path}"
        @client.saveFile urlPath, filePath, (error, response, body) =>
            @checkError error, response, body, 200, callback

    # Remove from db given file of given model.
    removeFile: (model, path, callback) ->
        urlPath = "data/#{model.id}/attachments/#{path}"
        @client.del urlPath, (error, response, body) =>
            @checkError error, response, body, 204, callback

    # Check if an error occurred. If any, it returns an a proper error.
    checkError: (error, response, body, code, callback) ->
        if error
            callback error
        else if response.statusCode != code
            callback new Error(body)
        else
            callback null

    # Create a new couchdb view which is typed with current model type.
    defineRequest: (model, name, request, callback) ->
        view = map: """
        function (doc) {
          if (doc.docType === "#{model}") {
            filter = #{request.toString()};
            filter(doc);
          }
        }
        """

        path = "request/#{model.toLowerCase()}/#{name.toLowerCase()}/"
        @client.put path, view, (error, response, body) =>
            @checkError error, response, body, 200, callback

    # Return defined request result.
    request: (model, name, params, callback) ->
        callback = params if typeof(params) == "function"
        
        path = "request/#{model.toLowerCase()}/#{name.toLowerCase()}/"
        @client.post path, params, (error, response, body) =>
            if error
                callback error
            else if response.statusCode != 200
                callback new Error(body)
            else
                results = []
                for doc in body
                    doc.value.id = doc.value._id
                    results.push new @_models[model].model(doc.value)
                callback null, results

    # Delete request that match given name for current type.
    removeRequest: (model, name, callback) ->
        path = "request/#{model.toLowerCase()}/#{name.toLowerCase()}/"
        @client.del path, (error, response, body) =>
            @checkError error, response, body, 204, callback

    # Delete all results that should be returned by the request.
    requestDestroy: (model, name, params, callback) ->
        callback = params if typeof(params) == "function"
        
        path = "request/#{model.toLowerCase()}/#{name.toLowerCase()}/destroy/"
        @client.put path, params, (error, response, body) =>
            @checkError error, response, body, 204, callback
