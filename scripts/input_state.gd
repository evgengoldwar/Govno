extends RefCounted
## Per-frame player intent, merged from keyboard and touch.

var mx := 0.0
var my := 0.0
var jump_pressed := false
var jump_held := false
var attack_held := false
var dash_pressed := false
var heal_pressed := false
var interact_pressed := false
var form_sel := ""
var form_cycle := 0
var map_pressed := false
var pause_pressed := false
