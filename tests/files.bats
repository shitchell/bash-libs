#!/usr/bin/env bats

load '../files.sh'

# Test mkuniq function
@test "mkuniq creates a unique filename" {
    touch "testfile"
    run mkuniq "testfile"
    [ "$status" -eq 0 ]
    [ "$output" = "testfile.1" ]
    rm "testfile"
}

@test "mkuniq returns the same filename if it does not exist" {
    run mkuniq "newfile"
    [ "$status" -eq 0 ]
    [ "$output" = "newfile" ]
}

# Test is-java-class function
@test "is-java-class returns 2 if no file is specified" {
    run is-java-class ""
    [ "$status" -eq 2 ]
    [ "$output" = "error: no filepath specified" ]
}

@test "is-java-class returns 3 if file does not exist" {
    run is-java-class "nonexistentfile.java"
    [ "$status" -eq 3 ]
    [ "$output" = "nonexistentfile.java: error: file 'nonexistentfile.java' does not exist" ]
}

@test "is-java-class returns 4 if file is a directory" {
    mkdir "testdir"
    run is-java-class "testdir"
    [ "$status" -eq 4 ]
    [ "$output" = "testdir: error: is a directory" ]
    rmdir "testdir"
}

@test "is-java-class returns 5 if file is a symlink" {
    touch "realfile.java"
    ln -s "realfile.java" "symlinkfile.java"
    run is-java-class "symlinkfile.java"
    [ "$status" -eq 5 ]
    [ "$output" = "symlinkfile.java: error: is a symlink" ]
    rm "realfile.java" "symlinkfile.java"
}

@test "is-java-class returns 6 if file has no extension" {
    touch "filewithoutextension"
    run is-java-class "filewithoutextension"
    [ "$status" -eq 6 ]
    [ "$output" = "filewithoutextension: error: no extension" ]
    rm "filewithoutextension"
}

@test "is-java-class returns 7 if file has an invalid extension" {
    touch "invalidfile.txt"
    run is-java-class "invalidfile.txt"
    [ "$status" -eq 7 ]
    [ "$output" = "invalidfile.txt: error: invalid extension '.txt'" ]
    rm "invalidfile.txt"
}

@test "is-java-class returns 0 for a valid java class file" {
    echo "public class TestClass {}" > "TestClass.java"
    run is-java-class "TestClass.java"
    [ "$status" -eq 0 ]
    [ "$output" = "TestClass.java: java class" ]
    rm "TestClass.java"
}

@test "is-java-class returns 1 for a file that is not a java class" {
    echo "This is not a java class" > "notaclass.java"
    run is-java-class "notaclass.java"
    [ "$status" -eq 1 ]
    [ "$output" = "notaclass.java: error: file is not a java class" ]
    rm "notaclass.java"
}
