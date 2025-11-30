#!/usr/bin/env bash

cd /apps/kohya_ss
source /workspace/.cache/venvs/kohya_ss/bin/activate
git checkout master
git pull
pip3 install -r requirements.txt
pip3 install .
