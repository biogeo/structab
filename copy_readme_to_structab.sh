#!/bin/bash
sed 's/^/% /' README.md > structab.m
echo '' >> structab.m
echo 'help structab;' >> structab.m
