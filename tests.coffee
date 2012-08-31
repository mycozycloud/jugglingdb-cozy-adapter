should = require('chai').Should()
async = require('async')
Client = require("request-json").JsonClient


client = new Client "http://localhost:7000/"

Schema = require('jugglingdb').Schema
schema = new Schema 'memory'
require("./src/cozy_data_system").initialize(schema)

Note = schema.define 'Note',
    title:     { type: String, length: 255 }
    content:   { type: Schema.Text }


describe "Existence", ->

    before (done) ->
        client.post 'data/321/', {"value":"created value"}, \
            (error, response, body) ->
            done()

    after (done) ->
        client.del "data/321/", (error, response, body) ->
            done()


    describe "Check Existence of a Document that does not exist in database", ->

        it "When I check existence of Document with id 123", \
                (done) ->
            Note.exists 123, (err, isExist) =>
                should.not.exist err
                @isExist = isExist
                done()

        it "Then false should be returned", ->
            @isExist.should.not.be.ok

    describe "Check Existence of a Document that does exist in database", ->

        it "When I check existence of Document with id 321", \
                (done) ->
            Note.exists 321, (err, isExist) =>
                should.not.exist err
                @isExist = isExist
                done()

        it "Then true should be returned", ->
            @isExist.should.be.ok


describe "Find", ->

    before (done) ->
        client.post 'data/321/',
            title: "my note"
            content: "my content"
            docType: "Note"
            , (error, response, body) ->
            done()

    after (done) ->
        client.del "data/321/", (error, response, body) ->
            done()


    describe "Find a note that does not exist in database", ->

        it "When I claim note with id 123", (done) ->
            Note.find 123, (err, note) =>
                @note = note
                done()

        it "Then null should be returned", ->
            should.not.exist @note

    describe "Find a note that does exist in database", ->

        it "When I claim note with id 321", (done) ->
            Note.find 321, (err, note) =>
                @note = note
                done()

        it "Then I should retrieve my note ", ->
            should.exist @note
            @note.title.should.equal "my note"
            @note.content.should.equal "my content"


describe "Create", ->
             
    before (done) ->
        client.post 'data/321/', {
            title: "my note"
            content: "my content"
            docType: "Note"
            } , (error, response, body) ->
            done()

    after (done) ->
        client.del "data/321/", (error, response, body) ->
            client.del "data/987/", (error, response, body) ->
                done()

    describe "Try to create a Document existing in Database", ->
        after ->
            @err = null
            @note = null

        it "When create a document with id 321", (done) ->
            Note.create { id: "321", "content":"created value"}, (err, note) =>
                @err = err
                @note = note
                done()

        it "Then an error is returned", ->
            should.exist @err

    describe "Create a new Document with a given id", ->
        
        before ->
            @id = "987"

        after ->
            @err = null
            @note = null

        it "When I create a document with id 987", (done) ->
            Note.create { id: @id, "content": "new note" }, (err, note) =>
                @err = err
                @note = note
                done()

        it "Then this should be set on document", ->
            should.not.exist @err
            should.exist @note
            @note.id.should.equal @id

        it "And the Document with id 987 should exist in Database", (done) ->
            Note.exists  @id, (err, isExist) =>
                should.not.exist err
                isExist.should.be.ok
                done()

        it "And the Document in DB should equal the sent Document", (done) ->
            Note.find  @id, (err, note) =>
                should.not.exist err
                note.id.should.equal @id
                note.content.should.equal "new note"
                done()


    describe "Create a new Document without an id", ->
                
        before ->
            @id = null

        after (done) ->
            @note.destroy =>
                @err = null
                @note = null
                done()

        it "When I create a document without an id", (done) ->
            Note.create { "title": "cool note", "content": "new note" }, (err, note) =>
                @err = err if err
                @note = note
                done()

        it "Then the id of the new Document should be returned", ->
            should.not.exist @err
            should.exist @note.id
            @id = @note.id

        it "And the Document should exist in Database", (done) ->
            Note.exists  @id, (err, isExist) =>
                should.not.exist err
                isExist.should.be.ok
                done()

        it "And the Document in DB should equal the sent Document", (done) ->
            Note.find  @id, (err, note) =>
                should.not.exist err
                note.id.should.equal @id
                note.content.should.equal "new note"
                done()



describe "Update", ->

    before (done) ->
        data =
            title: "my note"
            content: "my content"
            docType: "Note"

        client.post 'data/321/', data, (error, response, body) ->
            done()
        @note = new Note data

    after (done) ->
        client.del "data/321/", (error, response, body) ->
            done()


    describe "Try to Update a Document that doesn't exist", ->
        after ->
            @err = null

        it "When I update a document with id 123", (done) ->
            @note.id = "123"
            @note.save (err) =>
                @err = err
                done()

        it "Then an error is returned", ->
            should.exist @err

    describe "Update a Document", ->

        it "When I update document with id 321", (done) ->
            @note.id = "321"
            @note.title = "my new title"
            @note.save (err) =>
                @err = err
                done()

        it "Then no error is returned", ->
            should.not.exist @err

        it "And the old document must have been replaced in DB", (done) ->
            Note.find @note.id, (err, updatedNote) =>
                should.not.exist err
                updatedNote.id.should.equal "321"
                updatedNote.title.should.equal "my new title"
                done()


describe "Update attributes", ->

    before (done) ->
        data =
            title: "my note"
            content: "my content"
            docType: "Note"

        client.post 'data/321/', data, (error, response, body) ->
            done()
        @note = new Note data

    after (done) ->
        client.del "data/321/", (error, response, body) ->
            done()


    describe "Try to update attributes of a document that doesn't exist", ->
        after ->
            @err = null

        it "When I update a document with id 123", (done) ->
            @note.updateAttributes title: "my new title", (err) =>
                @err = err
                done()

        it "Then an error is returned", ->
            should.exist @err

    describe "Update a Document", ->

        it "When I update document with id 321", (done) ->
            @note.id = "321"
            @note.updateAttributes title: "my new title", (err) =>
                @err = err
                done()

        it "Then no error is returned", ->
            should.not.exist @err

        it "And the old document must have been replaced in DB", (done) ->
            Note.find @note.id, (err, updatedNote) =>
                should.not.exist err
                updatedNote.id.should.equal "321"
                updatedNote.title.should.equal "my new title"
                done()



describe "Upsert attributes", ->

    after (done) ->
        client.del "data/654/", (error, response, body) ->
            done()

    describe "Upsert a non existing document", ->
        it "When I upsert document with id 654", (done) ->
            @data =
                id: "654"
                title: "my note"
                content: "my content"
            
            Note.updateOrCreate @data, (err) =>
                @err = err
                done()

        it "Then no error should be returned.", ->
            should.not.exist @err

        it "Then the document with id 654 should exist in Database", (done) ->
            Note.find @data.id, (err, updatedNote) =>
                should.not.exist err
                updatedNote.id.should.equal "654"
                updatedNote.title.should.equal "my note"
                done()

    describe "Upsert an existing Document", ->

        it "When I upsert document with id 654", (done) ->
            @data =
                id: "654"
                title: "my new title"
            
            Note.updateOrCreate @data, (err, note) =>
                should.not.exist note
                @err = err
                done()

        it "Then no data should be returned", ->
            should.not.exist @err

        it "Then the document with id 654 should be updated", (done) ->
            Note.find @data.id, (err, updatedNote) =>
                should.not.exist err
                updatedNote.id.should.equal "654"
                updatedNote.title.should.equal "my new title"
                done()


describe "Delete", ->
    before (done) ->
        client.post 'data/321/', {
            title: "my note"
            content: "my content"
            docType: "Note"
            } , (error, response, body) ->
            done()

    after (done) ->
        client.del "data/321/", (error, response, body) ->
            client.del "data/987/", (error, response, body) ->
                done()


    describe "Deletes a document that is not in Database", ->

        it "When I delete Document with id 123", (done) ->
            note = new Note id:123
            note.destroy (err) =>
                @err = err
                done()

        it "Then an error should be returned", ->
            should.exist @err

    describe "Deletes a document from database", ->

        it "When I delete document with id 321", (done) ->
            note = new Note id:321
            note.destroy (err) =>
                @err = err
                done()

        it "Then no error is returned", ->
            should.not.exist @err

        it "And Document with id 321 shouldn't exist in Database", (done) ->
            Note.exists 321, (err, isExist) =>
                isExist.should.not.be.ok
                done()

