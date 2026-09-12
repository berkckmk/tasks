#!/bin/bash

git pull

git add .

git commit -m "${1:-Auto update}"

git push