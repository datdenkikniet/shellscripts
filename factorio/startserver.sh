#!/bin/bash
ret=1
while [ $ret -eq 1 ]; do
        /home/factorio/factorio/bin/x64/factorio --use-server-whitelist --server-whitelist /home/factorio/server-whitelist.json --server-settings /home/factorio/server-settings.json --start-server /home/factorio/my-save.zip
        ret=$?
done
# ./factorio/bin/x64/factorio --server-settings server-settings.json --start-server my-save.zip
