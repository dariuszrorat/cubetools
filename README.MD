## Cube tools

Various cube conversion tools written in Lazarus/Free Pascal

### Commandline tools

**Cube to cube conversion**
```
Usage: cube2cube [options] <infile> <outfile>

OPTIONS:

    -l level  set cube level
    -o fmt    set output format

       output formats: A = Adobe (default), D = Davinci
```

Example:
Convert from level 2 to 3
test.cube

```
TITLE "Test_Cube"
DOMAIN_MIN 0.0 0.0 0.0
DOMAIN_MAX 1.0 1.0 1.0
LUT_3D_SIZE 2
0.000000000 0.000000000 0.000000000
1.000000000 0.000000000 0.000000000
0.000000000 1.000000000 0.000000000
1.000000000 1.000000000 0.000000000
0.000000000 0.000000000 1.000000000
1.000000000 0.000000000 1.000000000
0.000000000 1.000000000 1.000000000
1.000000000 1.000000000 1.000000000
```

```
cube2cube -l 3 test.cube test2.cube
```

test2.cube
```
TITLE "Test_Cube"
DOMAIN_MIN 0.0 0.0 0.0
DOMAIN_MAX 1.0 1.0 1.0
LUT_3D_SIZE 3
0.000000000 0.000000000 0.000000000
0.500000000 0.000000000 0.000000000
1.000000000 0.000000000 0.000000000
0.000000000 0.500000000 0.000000000
0.500000000 0.500000000 0.000000000
1.000000000 0.500000000 0.000000000
0.000000000 1.000000000 0.000000000
0.500000000 1.000000000 0.000000000
1.000000000 1.000000000 0.000000000
0.000000000 0.000000000 0.500000000
0.500000000 0.000000000 0.500000000
1.000000000 0.000000000 0.500000000
0.000000000 0.500000000 0.500000000
0.500000000 0.500000000 0.500000000
1.000000000 0.500000000 0.500000000
0.000000000 1.000000000 0.500000000
0.500000000 1.000000000 0.500000000
1.000000000 1.000000000 0.500000000
0.000000000 0.000000000 1.000000000
0.500000000 0.000000000 1.000000000
1.000000000 0.000000000 1.000000000
0.000000000 0.500000000 1.000000000
0.500000000 0.500000000 1.000000000
1.000000000 0.500000000 1.000000000
0.000000000 1.000000000 1.000000000
0.500000000 1.000000000 1.000000000
1.000000000 1.000000000 1.000000000
```

**Cube to MGA conversion**

```
Usage: cube2mga <cubefile> [<mgafile>]
```

output from test cube level 2

```
#HEADER
#filename: test.mga
#type: 3D cube file
#format: 1.00
#created:
#owner: technicolor
#title: Test_Cube
#END

channel 3d
in 8
out 65536

format lut

values	red	green	blue
0	0	0	0
1	0	0	65535
2	0	65535	0
3	0	65535	65535
4	65535	0	0
5	65535	0	65535
6	65535	65535	0
7	65535	65535	65535
```

**Cube to PPM Hald CLUT conversion**

```
Usage: cube2ppm [options] <cubefile> [<ppmfile>]

OPTIONS:

    -t        use PPM text mode
    -l level  set HALD CLUT level
```

**MGA to Cube conversion**

```
Usage: mga2cube <mgafile> [<cubefile>]
```

**PPM Hald CLUT correction**

```
Usage: ppmclut <infile> <clutfile> <outfile>
```

**PPM cube correction**

```
Usage: ppmcube <infile> <cubefile> <outfile>
```

### Cube / Hald CLUT builder

Useful tool to build Cube and Hald CLUT

![Cube builder.](/images/cubebuilder.png "Cube builder.")

![Cube builder.](/images/negative.png "Cube builder negative.")

![Cube builder.](/images/grayscale.png "Cube builder grayscale.")