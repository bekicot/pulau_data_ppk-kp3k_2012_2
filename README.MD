# Indonesian Island
[![Build Status](https://travis-ci.org/bekicot/pulau_data_ppk-kp3k_2012_2.svg?branch=master)](https://travis-ci.org/bekicot/pulau_data_ppk-kp3k_2012_2)

> List of island in Indonesia as published by ppk-kp3k

## Pre processed Dataset
To retrieve the pre-processed Island, visit [With Data - Branch](https://github.com/bekicot/pulau_data_ppk-kp3k_2012_2/tree/with-data/results) or the [Release Page](https://github.com/bekicot/pulau_data_ppk-kp3k_2012_2/releases) to download the zipped data.

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
