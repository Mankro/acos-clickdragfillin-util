###
Utility functions for point-and-click, drag-and-drop, and text fill-in exercises.
###
fs = require('fs')
path = require('path')
recursiveReaddir = require('recursive-readdir')
Exercise = require('./exercise')

# name of the directory in the content package that contains the exercises (XML files)
exercisesDirName = 'exercises'


# Adds a content package (at ACOS server startup)
registerContentPackage = (contentPackagePrototype, contentPackageDir) ->
  # Autodiscover exercises: any XML file in the content package directory "exercises"
  # is assumed to be an exercise (with a corresponding JSON file). The files may be nested
  # in subdirectories.
  exercisesDir = path.join(contentPackageDir, exercisesDirName)
  recursiveReaddir(exercisesDir, (err, files) ->
    # files include only files, no directories
    if err
      console.error err
      throw err
    order = 0
    for filepath in files
      if (/\.xml$/.test(filepath))
        # since XML files in different subdirectories might be using the same filename,
        # we must keep the directory path in the exercise name (unique identifier within
        # the content package). Slash / characters are replaced with dashes - so that
        # the exercise names do not mess up URL paths. Assume that the XML files
        # are named without any dashes "-".
        fullPath = filepath
        # Remove the leading directory path so that the path inside the exercises directory is left.
        filepath = filepath.substring(exercisesDir.length + 1)
        # warn the user if dashes "-" are used in the filename
        if filepath.indexOf('-') != -1
          console.warn "The name of the exercise file #{fullPath} in the
            content package #{contentPackagePrototype.namespace} of content type
            #{contentPackagePrototype.contentTypeNamespace} contains dashes (-) even though
            it is not supported and should result in errors"
        
        filepath = filepath.replace(new RegExp(path.sep, 'g'), '-') # replace / with -
        
        # Get the filename without the extension
        exerciseName = filepath.substring(0, filepath.length - 4)
        
        contentPackagePrototype.meta.contents[exerciseName] = {
          'title': exerciseName,
          'description': '',
          'order': order++
        }
        
        contentPackagePrototype.meta.teaserContent.push(exerciseName)
  )


# Initializes the exercise (called when a user starts an exercise)
# contentTypePrototype: content type object
# njEnv: nunjucks environment that has been configured with the path to the templates
#   of the content type (exercise_head.html and exercise_body.html)
# exerciseCache: exercise cache object of the content type
# req, params, handlers, cb: the same as in the initialize function of content types
initializeContentType = (contentTypePrototype, njEnv, exerciseCache, req, params, handlers, cb) ->
  contentPackage = handlers.contentPackages[req.params.contentPackage]
  
  readExerciseXML = (exerciseName, cache) ->
    filepath = exerciseName.replace(/-/g, path.sep) # replace - with /
    fs.readFile path.join(contentPackage.getDir(), exercisesDirName, filepath + '.xml'), 'utf8', (err, xml_data) ->
      if err
        # no exercise file with this name, or other IO error
        # a user could manipulate URLs and probe different values
        console.error err
        renderError(err, params)
        cb()
        return
      
      parser = new Exercise(contentTypePrototype.namespace)
      parser.parseXml xml_data, (err, tree, head) ->
        if err
          renderError(err, params)
          cb()
        else
          # JSON file contains data for the clickable elements (correct/wrong, feedback, ...)
          userDefinedJsonFilepath = path.join(contentPackage.getDir(), exercisesDirName, filepath + '.json')
          
          fs.readFile userDefinedJsonFilepath, 'utf8', (err, data) ->
            if err
              payload = {}
            else
              payload = JSON.parse data
              
            # Add autogenerated payload
            payload = parser.jsonPayload(payload, tree)

            cache.headContent = njEnv.render 'exercise_head.html', {
              headContent: if head? then head.html(omitRoot: true) else '',
              payload: JSON.stringify payload
            }

            cache.bodyContent = njEnv.render 'exercise_body.html', {
              exercise: tree.html(omitRoot: true)
            }
            
            # parsed exercise data was added to the cache, now add it to the response
            params.headContent += cache.headContent
            params.bodyContent += cache.bodyContent
            
            cb()


  if !exerciseCache[req.params.contentPackage]?
    exerciseCache[req.params.contentPackage] = {}
  if !exerciseCache[req.params.contentPackage][params.name]?
    # not cached yet
    exerciseCache[req.params.contentPackage][params.name] = {}
    readExerciseXML params['name'], exerciseCache[req.params.contentPackage][params.name]
  else
    cachedVal = exerciseCache[req.params.contentPackage][params.name]
    params.headContent += cachedVal.headContent
    params.bodyContent += cachedVal.bodyContent
    # assume that the content package does not need to initialize anything (this content type takes
    # care of everything), so do not call the initialize function from the content package
    cb()


renderError = (error, params) ->
  params.bodyContent = "<div class=\"alert-danger\">\n" + error.toString() + "\n</div>"


# write an event to the (content package specific) log
# logDirectory: path to the log directory of the ACOS server
# contentTypePrototype: content type object
# payload, req, protocolPayload: the same as in the handleEvent function of content types
writeExerciseLogEvent = (logDirectory, contentTypePrototype, payload, req, protocolPayload) ->
  dir = logDirectory + "/#{ contentTypePrototype.namespace }/" + req.params.contentPackage
  # path like log_dir/"contenttype"/"contentpackage", log files for each exercise will be created there
  
  fs.mkdir(dir, 0o0775, (err) ->
    if (err && err.code != 'EEXIST')
      # error in creating the directory, the directory does not yet exist
      console.error err
      return
    filename = req.params.name + '.log'
    # the exercise name should be a safe filename for the log file too since
    # the exercise names are based on the XML filenames and the name parameter
    # has already passed the ACOS server URL router regular expression
    data = new Date().toISOString() + ' ' + JSON.stringify(payload) + ' ' + JSON.stringify(protocolPayload || {}) + '\n'
    fs.writeFile(dir + '/' + filename, data, { flag: 'a' }, ((err) -> ))
  )


module.exports =
  Exercise: Exercise
  registerContentPackage: registerContentPackage
  initializeContentType: initializeContentType
  renderError: renderError
  writeExerciseLogEvent: writeExerciseLogEvent

