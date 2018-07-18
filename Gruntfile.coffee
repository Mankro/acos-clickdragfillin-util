module.exports = (grunt) ->
  grunt.initConfig
    coffee:
      options:
        bare: true
        join: true
        separator: "\n\n"
      backend:
        files:
          'index.js': ['index.coffee']
          'exercise.js': ['exercise.coffee']
    uglify:
      production:
        options:
          output:
            comments: false
        files:
          'static/resize-feedback-iframe.js': ['static-src/resize-feedback-iframe.js']

  # Load the plugins (tasks "coffee", "uglify")
  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-uglify-es'

  # Default tasks
  grunt.registerTask 'default', ['coffee', 'uglify']
  grunt.registerTask 'dev', ['coffee']

