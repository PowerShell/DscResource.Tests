var gulp = require("gulp");
var concat = require("gulp-concat");
var through2 = require("through2");
var markdownlint = require("markdownlint");

gulp.task("test-mdsyntax", function task() {
  var paths = [];

  var i = process.argv.indexOf("--dscresourcespath");
  if (i > -1) {
    paths.push(process.argv[i + 1] + '/**/*.md');
  }

  var j = process.argv.indexOf("--rootpath");
  if (j > -1) {
    paths.push(process.argv[j + 1] + '/*.md');
  }

  var settingsPath;
  var indexOfSettingsPathArgument = process.argv.indexOf("--settingspath");
  if (indexOfSettingsPathArgument > -1) {
    settingsPath = process.argv[indexOfSettingsPathArgument + 1];
  }
  else
  {
    settingsPath = "./.markdownlint.json"
  }

  return gulp.src(paths, { "read": false })
    .pipe(through2.obj(function obj(file, enc, next) {
      markdownlint(
        {
          "files": [file.path],
          "config": require(settingsPath)
        },
        function callback(err, result) {
          var resultString = (result || "").toString();
          if (resultString) {
            file.contents = new Buffer(resultString);
          }
          next(err, file);
        });
    }))
    .pipe(concat("markdownissues.txt", { newLine: "\r\n" }))
    .pipe(gulp.dest("."));
});
