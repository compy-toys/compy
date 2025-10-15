### Text coordinates

We have some text utilities:
* WrappedText
* VisibleContent

This document will lay out the various coordinate spaces.

First, we have the original:
```
█Bacon ipsum dolor amet ribeye hamburger
c█hislic pork short ribs
po█rchetta. Pork loin meatball ball tip
por█k chop capicola fatback beef sausage short
loin█ bresaola venison.
```
5 lines, up to ~50 chars max.
Let's call this 'normal coords'.

Then we can wrap this, for example, at 20:
```
█Bacon ipsum dolor  | 1
amet ribeye hamburg |
er                  |
c█hislic pork short | 2
 ribs               |
po█rchetta. Pork lo | 3
in meatball ball ti |
p                   |
por█k chop capicola | 4
 fatback beef sausa |
 ge short           |
loin█ bresaola veni | 5
son.                |
```
It's now 13 lines, up to 20 chars.
Call these 'wrapped coords'.

Then add scrolling, say, 5 lines:
```
por█k chop capicola | 4
 fatback beef sausa |
 ge short           |
loin█ bresaola veni | 5
son.                |
```
We arrive at 'visible coords'.

#### convert

What is `visible(3, 3)` in the others?
* `wrapped(11, 3)`
* `normal(4, 41)`
