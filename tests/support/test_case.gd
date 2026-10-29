extends SceneTree
# Shared harness for the headless tests.
#
# Tests used to copy a 4-8 line `check()` implementation each (143 copies, three
# different failure conventions). Extend this script instead and keep the body:
#
#   extends "res://tests/support/test_case.gd"
#   func _initialize():
#       check(state == expected, "state matches")
#       ...
#       print("SUITE checks=", checks, " failures=", failures)
#       quit(0 if failures else 1)
#
# `check` records a failure and lets the test continue, which is what most tests
# want. `require` additionally asserts so a test that cannot usefully continue
# stops the way it did before (the checked runner treats the assertion as a
# failure even though Godot may exit zero).
var checks=0
var failures=0

func check(value,label=""):
    checks+=1
    if not value:
        failures+=1
        printerr("FAIL: ",label)

func require(value,label=""):
    checks+=1
    if not value:
        failures+=1
        printerr("FAIL: ",label)
        assert(value,label)
