#!/usr/bin/env bash
gcc -shared -fPIC -I./vendor/raygui -o ./vendor/raygui/libraygui.so ./vendor/raygui/raygui.c -lraylib

