# Indonesian Island
[![Build Status](https://travis-ci.org/bekicot/pulau_data_ppk-kp3k_2012_2.svg?branch=master)](https://travis-ci.org/bekicot/pulau_data_ppk-kp3k_2012_2)

> List of island in Indonesia as published by ppk-kp3k

## Usage
```
ruby extract_contents_csv.rb -r
```
Without the `-r` arguments, it will reuse the html that has been cached in the system


## Options
```
$ ruby extract_contents_csv.rb -h
Parsing Arguments
Usage: example.rb [options]
    -r, --rebuild-cache              Rebuild html cache
    -t, --travis                     Run as travis

```

## Output Directory

```
results
```
